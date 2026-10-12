package com.formulalote.mobile;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteException;
import android.webkit.JavascriptInterface;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

/** Only the bundled WebView origin may call this bridge. Never load remote pages. */
public final class DatabaseBridge {
    private final Context context;
    private final File dbFile;
    private SQLiteDatabase db;

    public DatabaseBridge(Context context) {
        this.context = context.getApplicationContext();
        dbFile = this.context.getDatabasePath("artesanal.sqlite");
        try {
            if (!dbFile.exists()) {
                File parent = dbFile.getParentFile();
                if (parent != null && !parent.exists() && !parent.mkdirs()) throw new IllegalStateException("No se creó directorio DB");
                try (InputStream in = this.context.getAssets().open("artesanal.sqlite"); OutputStream out = new FileOutputStream(dbFile)) {
                    byte[] buf = new byte[16384]; int n;
                    while ((n=in.read(buf)) >= 0) out.write(buf,0,n);
                }
            }
            open();
        } catch(Exception e) {throw new IllegalStateException("Error iniciando SQLite: " + e.getMessage(),e);}
    }
    private void open() {
        db = SQLiteDatabase.openDatabase(dbFile.getAbsolutePath(), null, SQLiteDatabase.OPEN_READWRITE);
        db.setForeignKeyConstraintsEnabled(true);
        migrateIfNeeded();
        try(Cursor c = db.rawQuery("PRAGMA integrity_check",null)) {
            if (!c.moveToFirst() || !"ok".equals(c.getString(0))) throw new SQLiteException("Integridad DB inválida");
        }
    }
    /** Automatic migration on existing installations; never replace user database with seed. */
    private void migrateIfNeeded() {
        int version;
        try(Cursor c=db.rawQuery("PRAGMA user_version",null)){c.moveToFirst();version=c.getInt(0);}
        if(version==61)return;
        if(version!=60)throw new SQLiteException("Versión SQLite no soportada: "+version);
        StringBuilder script=new StringBuilder();
        try(InputStream in=context.getAssets().open("migration_v61.sql")) {
            byte[] buf=new byte[8192];int n;while((n=in.read(buf))!=-1)script.append(new String(buf,0,n,java.nio.charset.StandardCharsets.UTF_8));
        }catch(Exception e){throw new SQLiteException("No se pudo leer migración v6.1: "+e.getMessage());}
        db.beginTransaction();
        try{
            for(String part:script.toString().split("--V61_STATEMENT--")) {
                String stmt=part.trim();if(stmt.isEmpty())continue;
                if(stmt.endsWith(";"))stmt=stmt.substring(0,stmt.length()-1);
                db.execSQL(stmt);
            }
            db.setTransactionSuccessful();
        } finally {db.endTransaction();}
    }
    @JavascriptInterface public String newId(){return UUID.randomUUID().toString();}
    public File getDbFile(){return dbFile;}

    @JavascriptInterface public synchronized String execute(String requestJSON) {
        JSONObject out = new JSONObject(); boolean inTx = false;
        try {
            JSONObject in = new JSONObject(requestJSON);
            JSONArray steps = in.getJSONArray("steps");
            boolean tx = in.optBoolean("tx",false);
            JSONArray results = new JSONArray();
            if(tx){db.beginTransactionNonExclusive();inTx=true;}
            for(int k=0;k<steps.length();k++){
                JSONObject op=steps.getJSONObject(k);
                String sql=op.getString("sql");
                JSONArray pars=op.optJSONArray("params");
                Object[] args=toParams(pars);
                String mode=op.optString("mode","run");
                if (mode.equals("all")||mode.equals("one")){
                    String[] strings=new String[args.length];
                    for(int j=0;j<args.length;j++)strings[j]=args[j]==null?null:String.valueOf(args[j]);
                    try(Cursor c=db.rawQuery(sql,strings)){
                        JSONArray rows = new JSONArray();
                        while(c.moveToNext()){
                            JSONObject row=new JSONObject();
                            for(int col=0;col<c.getColumnCount();col++){
                                String name=c.getColumnName(col);int type=c.getType(col); Object value;
                                switch(type){case Cursor.FIELD_TYPE_NULL:value=JSONObject.NULL;break;case Cursor.FIELD_TYPE_INTEGER:value=c.getLong(col);break;case Cursor.FIELD_TYPE_FLOAT:value=c.getDouble(col);break;case Cursor.FIELD_TYPE_BLOB:throw new IllegalArgumentException("Blob no disponible en JSON");default:value=c.getString(col);}
                                row.put(name,value);
                            }
                            rows.put(row);
                            if(mode.equals("one")) break;
                        }
                        results.put(mode.equals("one")?(rows.length()==0?JSONObject.NULL:rows.getJSONObject(0)):rows);
                    }
                } else {
                    db.execSQL(sql,args);
                    results.put(JSONObject.NULL);
                }
            }
            if(inTx){db.setTransactionSuccessful();}
            out.put("results",results);
        } catch(Exception e) {
            try {out.put("error",e.getMessage()==null?"Error SQLite":e.getMessage());}catch(Exception ignored){}
        } finally {
            if(inTx)db.endTransaction();
        }
        return out.toString();
    }
    private Object[] toParams(JSONArray values) throws Exception {
        if(values==null)return new Object[0]; Object[] arr=new Object[values.length()];
        for(int i=0;i<arr.length;i++){ Object v=values.opt(i);if(v==JSONObject.NULL||v==null)arr[i]=null;else if(v instanceof Boolean)arr[i]=((Boolean)v)?1:0;else if(v instanceof Number||v instanceof String)arr[i]=v;else throw new IllegalArgumentException("Parámetro inválido"); }
        return arr;
    }
    /** SQLite consistent backup: close/checkpoint before copying; single writer in app. */
    public synchronized File snapshotBackup() throws Exception {
        if(db.inTransaction())throw new IllegalStateException("Espere a que termine la operación");
        db.rawQuery("PRAGMA wal_checkpoint(TRUNCATE)",null).close();
        db.close();
        File temp=File.createTempFile("respaldo_",".sqlite",context.getCacheDir());
        try(InputStream in=new java.io.FileInputStream(dbFile);OutputStream out=new FileOutputStream(temp)){
            byte[] b=new byte[16384];int n;while((n=in.read(b))!=-1)out.write(b,0,n);
        }finally{open();}
        return temp;
    }
    public synchronized void restore(File newDatabase) throws Exception {
        if(db.inTransaction())throw new IllegalStateException("Hay una operación en curso");
        SQLiteDatabase candidate=SQLiteDatabase.openDatabase(newDatabase.getAbsolutePath(),null,SQLiteDatabase.OPEN_READONLY);
        try(Cursor c=candidate.rawQuery("PRAGMA integrity_check",null)){
            if(!c.moveToFirst()||!"ok".equals(c.getString(0)))throw new SQLiteException("Respaldo corrupto");
        }
        try(Cursor c=candidate.rawQuery("SELECT value FROM settings WHERE key='schema_version'",null)){
            if(!c.moveToFirst()||!c.getString(0).startsWith("6."))throw new SQLiteException("Esquema incompatible. Se requiere versión 6.x");
        }
        try(Cursor c=candidate.rawQuery("PRAGMA foreign_key_check",null)){
            if(c.moveToFirst())throw new SQLiteException("Referencias inválidas en respaldo");
        }
        candidate.close();
        File safe = new File(context.getFilesDir(),"pre_restauracion.sqlite");
        File snapshot=snapshotBackup();
        java.nio.file.Files.copy(snapshot.toPath(),safe.toPath(),java.nio.file.StandardCopyOption.REPLACE_EXISTING);
        snapshot.delete();
        db.close();
        try{
            new File(dbFile.getAbsolutePath()+"-wal").delete();new File(dbFile.getAbsolutePath()+"-shm").delete();
            java.nio.file.Files.copy(newDatabase.toPath(),dbFile.toPath(),java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            open();
        }catch(Exception e){java.nio.file.Files.copy(safe.toPath(),dbFile.toPath(),java.nio.file.StandardCopyOption.REPLACE_EXISTING);open();throw e;}
    }
}