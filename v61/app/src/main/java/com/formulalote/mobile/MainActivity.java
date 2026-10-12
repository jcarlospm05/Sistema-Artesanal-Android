package com.formulalote.mobile;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.provider.MediaStore;
import android.content.ContentValues;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import android.webkit.JsResult;
import android.webkit.JsPromptResult;
import android.webkit.ValueCallback;
import android.print.PrintManager;
import android.print.PrintAttributes;
import android.webkit.WebResourceRequest;
import android.webkit.JavascriptInterface;
import android.graphics.Color;
import android.view.WindowManager;
import org.json.JSONObject;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.nio.file.Files;
import java.util.zip.*;
import java.security.MessageDigest;
import org.json.JSONArray;

public class MainActivity extends Activity {
    private WebView web;
    private DatabaseBridge store;
    private byte[] pendingSave;
    private String pendingMime;
    private ValueCallback<Uri[]> pendingFileSelection;
    private static final int SAVE_FILE=101, OPEN_BACKUP=102, FILE_CHOOSE=103;
    @Override public void onCreate(Bundle b){super.onCreate(b);
        getWindow().setStatusBarColor(Color.rgb(21,61,49));getWindow().setNavigationBarColor(Color.rgb(21,61,49));
        store=new DatabaseBridge(this);
        web=new WebView(this);setContentView(web);
        web.getSettings().setJavaScriptEnabled(true);web.getSettings().setDomStorageEnabled(true);
        web.getSettings().setAllowFileAccess(true);
        web.getSettings().setAllowFileAccessFromFileURLs(false);
        web.getSettings().setAllowUniversalAccessFromFileURLs(false);
        web.getSettings().setAllowContentAccess(true);
        web.getSettings().setMixedContentMode(android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        WebView.setWebContentsDebuggingEnabled(false);
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !r.getUrl().toString().startsWith("file:///android_asset/");}
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onJsAlert(WebView view,String url,String message,JsResult result){
                new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("Aceptar",(d,w)->result.confirm()).setOnCancelListener(d->result.cancel()).show();return true;
            }
            @Override public boolean onJsConfirm(WebView view,String url,String message,JsResult result){
                new AlertDialog.Builder(MainActivity.this).setMessage(message).setPositiveButton("Sí",(d,w)->result.confirm()).setNegativeButton("No",(d,w)->result.cancel()).setOnCancelListener(d->result.cancel()).show();return true;
            }
            @Override public boolean onJsPrompt(WebView view,String url,String message,String defaultValue,JsPromptResult result){
                android.widget.EditText input=new android.widget.EditText(MainActivity.this);input.setSingleLine(true);input.setText(defaultValue);
                new AlertDialog.Builder(MainActivity.this).setTitle(message).setView(input).setPositiveButton("Aceptar",(d,w)->result.confirm(input.getText().toString())).setNegativeButton("Cancelar",(d,w)->result.cancel()).setOnCancelListener(d->result.cancel()).show();return true;
            }
            @Override public boolean onShowFileChooser(WebView view,ValueCallback<Uri[]> callback,FileChooserParams params){
                if(pendingFileSelection!=null)pendingFileSelection.onReceiveValue(null);
                pendingFileSelection=callback;
                Intent intent=new Intent(Intent.ACTION_OPEN_DOCUMENT);intent.addCategory(Intent.CATEGORY_OPENABLE);intent.setType("image/*");intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                try{startActivityForResult(intent,FILE_CHOOSE);}catch(Exception e){pendingFileSelection=null;callback.onReceiveValue(null);toast("No se abrió selector de logo");}return true;
            }
        });
        web.addJavascriptInterface(store,"SQLiteBridge");
        web.addJavascriptInterface(new FileBridge(),"AndroidFiles");
        web.loadUrl("file:///android_asset/index.html");
    }
    private void signal(String js){runOnUiThread(()->web.evaluateJavascript(js,null));}
    private void toast(String msg){signal("window.nativeNotice?.("+JSONObject.quote(msg)+")");}
    private File privateDocs(){File out=new File(getFilesDir(),"documents");if(!out.exists()&&!out.mkdirs())throw new IllegalStateException("No se creó carpeta de comprobantes");return out;}
    private String sha(byte[] bytes)throws Exception{byte[] dig=MessageDigest.getInstance("SHA-256").digest(bytes);StringBuilder s=new StringBuilder();for(byte b:dig)s.append(String.format(java.util.Locale.ROOT,"%02x",b&255));return s.toString();}
    private byte[] readAll(File f)throws Exception{return Files.readAllBytes(f.toPath());}
    public final class FileBridge {
        @JavascriptInterface public void saveBase64(String filename,String mime,String base64){
            try{
                byte[] bytes=Base64.getDecoder().decode(base64.replaceFirst("^data:[^,]+,",""));
                saveFile(filename,mime,bytes);
            }catch(Exception e){toast(e.getMessage());}
        }
        @JavascriptInterface public void saveJson(String filename,String json){saveFile(filename,"application/json",json.getBytes(StandardCharsets.UTF_8));}
        @JavascriptInterface public void exportPackage(){
            try{
                File backup=store.snapshotBackup();
                File pkg=File.createTempFile("package_",".zip",getCacheDir());
                JSONObject manifest=new JSONObject();JSONObject hashes=new JSONObject();manifest.put("format","sistema-artesanal-v61");manifest.put("created_at",new java.util.Date().toString());
                try(ZipOutputStream zip=new ZipOutputStream(new FileOutputStream(pkg))){
                    byte[] dbdata=readAll(backup);addZip(zip,"database.sqlite",dbdata);hashes.put("database.sqlite",sha(dbdata));
                    File root=privateDocs();File[] dirs=root.listFiles();if(dirs!=null)for(File dir:dirs){if(!dir.isDirectory())continue;File[] entries=dir.listFiles();if(entries==null)continue;
                        for(File doc:entries){if(!doc.isFile()||!doc.getName().endsWith(".png"))continue;
                            String name="documents/"+dir.getName()+"/"+doc.getName();byte[] bytes=readAll(doc);addZip(zip,name,bytes);hashes.put(name,sha(bytes));}}
                    manifest.put("files",hashes);addZip(zip,"manifest.json",manifest.toString(2).getBytes(StandardCharsets.UTF_8));
                }finally{backup.delete();}
                saveFile("Respaldo_Artesanal_v6_1.zip","application/zip",readAll(pkg));pkg.delete();
            }catch(Exception e){toast("Error generando paquete: "+e.getMessage());}
        }
        private void addZip(ZipOutputStream z,String path,byte[] bytes)throws Exception{z.putNextEntry(new ZipEntry(path));z.write(bytes);z.closeEntry();}
        @JavascriptInterface public void exportSQLite(){
            try{File f=store.snapshotBackup();try(InputStream in=new FileInputStream(f);ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] b=new byte[16384];int n;while((n=in.read(b))!=-1)out.write(b,0,n);saveFile("Sistema_Artesanal_respaldo.sqlite","application/vnd.sqlite3",out.toByteArray());
            }finally{f.delete();}}catch(Exception e){toast("No se pudo exportar: "+e.getMessage());}
        }
        @JavascriptInterface public void importSQLite(){runOnUiThread(()->{
            Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.setType("*/*");i.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,OPEN_BACKUP);
        });}
        private Uri storePng(String filename,byte[] bytes) throws Exception {
            String folder=filename.startsWith("COT-")?"Cotizaciones":filename.startsWith("FAC-")?"Facturas":filename.startsWith("REC-")?"Recibos":"Otros";
            ContentValues cv=new ContentValues();cv.put(MediaStore.Images.Media.DISPLAY_NAME,filename);
            cv.put(MediaStore.Images.Media.MIME_TYPE,"image/png");
            cv.put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/Sistema Artesanal/"+folder);
            Uri uri=getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,cv);
            if(uri==null)throw new IOException("No se creó imagen");
            try(OutputStream out=getContentResolver().openOutputStream(uri)){if(out==null)throw new IOException("No se abrió el destino");out.write(bytes);}
            // Duplicate in protected app storage, included in complete backups.
            File dir=new File(privateDocs(),folder);if(!dir.exists()&&!dir.mkdirs())throw new IOException("No se creó carpeta privada");
            try(OutputStream privateOut=new FileOutputStream(new File(dir,filename))){privateOut.write(bytes);}
            return uri;
        }
        @JavascriptInterface public void savePng(String filename,String base64){
            try {byte[] bytes=Base64.getDecoder().decode(base64.replaceFirst("^data:[^,]+,",""));
                runOnUiThread(()->{try{storePng(filename,bytes);toast("PNG guardado en Imágenes / Sistema Artesanal");}catch(Exception e){toast(e.getMessage());}});
            }catch(Exception e){toast(e.getMessage());}
        }
        @JavascriptInterface public void printHtml(String title,String html){
            runOnUiThread(()->{
                WebView printer=new WebView(MainActivity.this);
                printer.getSettings().setJavaScriptEnabled(false);
                printer.setWebViewClient(new WebViewClient(){
                    @Override public void onPageFinished(WebView v,String url){
                        PrintManager pm=(PrintManager)getSystemService(PRINT_SERVICE);
                        pm.print(title,printer.createPrintDocumentAdapter(title),new PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build());
                    }
                });
                printer.loadDataWithBaseURL(null,"<!doctype html><html lang='es'><meta charset='utf-8'><style>body{font:14px Arial;padding:20px}table{width:100%;border-collapse:collapse}td,th{border-bottom:1px solid #ddd;padding:8px;text-align:left}</style><body>"+html+"</body></html>","text/html","utf-8",null);
            });
        }
        @JavascriptInterface public void sharePng(String filename,String base64){
            try {byte[] bytes=Base64.getDecoder().decode(base64.replaceFirst("^data:[^,]+,",""));runOnUiThread(()->{
                try{
                    Uri uri=storePng(filename,bytes);
                    Intent share=new Intent(Intent.ACTION_SEND);share.setType("image/png");share.putExtra(Intent.EXTRA_STREAM,uri);share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(share,"Compartir documento"));
                }catch(Exception e){toast(e.getMessage());}
            });}catch(Exception e){toast(e.getMessage());}
        }
    }
    private void saveFile(String name,String mime,byte[] bytes){runOnUiThread(()->{
        pendingSave=bytes;pendingMime=mime;
        Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.addCategory(Intent.CATEGORY_OPENABLE);i.setType(mime);i.putExtra(Intent.EXTRA_TITLE,name);
        startActivityForResult(i,SAVE_FILE);
    });}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);
        if(request==FILE_CHOOSE){if(pendingFileSelection!=null){pendingFileSelection.onReceiveValue(result==RESULT_OK&&data!=null&&data.getData()!=null?new Uri[]{data.getData()}:null);pendingFileSelection=null;}return;}
        if(result!=RESULT_OK||data==null||data.getData()==null)return;
        Uri uri=data.getData();
        if(request==SAVE_FILE){try(OutputStream out=getContentResolver().openOutputStream(uri)){if(out==null)throw new IOException("Sin acceso al destino");out.write(pendingSave);toast("Archivo guardado");}catch(Exception e){toast("Error guardando: "+e.getMessage());}finally{pendingSave=null;}}
        if(request==OPEN_BACKUP){try(InputStream in=getContentResolver().openInputStream(uri)){
            if(in==null)throw new IOException("Archivo inaccesible");File tmp=File.createTempFile("import_",".data",getCacheDir());try(OutputStream out=new FileOutputStream(tmp)){
                byte[] b=new byte[16384];int n;long total=0;while((n=in.read(b))!=-1){total+=n;if(total>100_000_000)throw new IOException("Respaldo demasiado grande");out.write(b,0,n);}}
            new AlertDialog.Builder(this).setTitle("¿Restaurar base de datos?")
                .setMessage("Sustituirá los datos actuales de este celular. Antes se guardará una copia local de seguridad. Asegúrate de tener otra copia externa.")
                .setNegativeButton("Cancelar",(a,b)->tmp.delete())
                .setPositiveButton("Restaurar",(a,b)->{try{restoreAny(tmp);web.reload();toast("Respaldo restaurado");}catch(Exception e){toast("Restauración cancelada: "+e.getMessage());}finally{tmp.delete();}}).show();
        }catch(Exception e){toast("No se abrió respaldo: "+e.getMessage());}}
    }
    private void restoreAny(File file)throws Exception{
        try(InputStream head=new FileInputStream(file)){
            byte[] magic=new byte[4];if(head.read(magic)!=4)throw new IOException("Archivo vacío");
            if(magic[0]!='P'||magic[1]!='K'){store.restore(file);return;}
        }
        File stage=new File(getCacheDir(),"stage_"+System.nanoTime());if(!stage.mkdirs())throw new IOException("No se creó staging");
        try{
            long total=0;java.util.Map<String,byte[]> entries=new java.util.LinkedHashMap<>();
            try(ZipInputStream zin=new ZipInputStream(new FileInputStream(file))){ZipEntry z;
                while((z=zin.getNextEntry())!=null){if(z.isDirectory())continue;String name=z.getName();
                    if(entries.containsKey(name)||!(name.equals("database.sqlite")||name.equals("manifest.json")||name.matches("documents/(Cotizaciones|Facturas|Recibos|Otros)/[A-Za-z0-9._-]+\\.png")))throw new IOException("Contenido ZIP inesperado");
                    ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buf=new byte[8192];int n;while((n=zin.read(buf))!=-1){total+=n;if(total>120_000_000L)throw new IOException("Copia demasiado grande");out.write(buf,0,n);}entries.put(name,out.toByteArray());
                }
            }
            if(!entries.containsKey("database.sqlite")||!entries.containsKey("manifest.json"))throw new IOException("Copia incompleta");
            JSONObject meta=new JSONObject(new String(entries.get("manifest.json"),StandardCharsets.UTF_8));
            if(!"sistema-artesanal-v61".equals(meta.optString("format")))throw new IOException("Formato de respaldo incompatible");
            JSONObject expected=meta.getJSONObject("files");if(expected.length()!=entries.size()-1)throw new IOException("Cantidad de archivos incompatible");
            for(String name:entries.keySet())if(!name.equals("manifest.json")&&!sha(entries.get(name)).equals(expected.optString(name)))throw new IOException("SHA256 no coincide: "+name);
            File stagedDb=new File(stage,"database.sqlite");Files.write(stagedDb.toPath(),entries.get("database.sqlite"));
            // Prepare document tree completely before replacing current files.
            File stagedDocs=new File(stage,"documents");if(!stagedDocs.mkdirs())throw new IOException("No se creó staging de documentos");
            for(String name:entries.keySet()){if(!name.startsWith("documents/"))continue;File target=new File(stagedDocs,name.substring("documents/".length()));File parent=target.getParentFile();if(!parent.exists()&&!parent.mkdirs())throw new IOException("No se creó subcarpeta");Files.write(target.toPath(),entries.get(name));}
            store.restore(stagedDb); // Validates SQLite integrity, foreign keys, schema and rolls back DB on failure.
            File current=new File(getFilesDir(),"documents");File old=new File(getFilesDir(),"documents_old_"+System.nanoTime());
            if(current.exists()&&!current.renameTo(old))throw new IOException("No se movió carpeta anterior");
            if(!stagedDocs.renameTo(current)){if(old.exists())old.renameTo(current);throw new IOException("No se instaló carpeta de documentos");}
            deleteTree(old);
        } finally {deleteTree(stage);}
    }
    private void deleteTree(File f){if(f==null||!f.exists())return;if(f.isDirectory()){File[] all=f.listFiles();if(all!=null)for(File child:all)deleteTree(child);}f.delete();}
    @Override public void onBackPressed(){if(web.canGoBack())web.goBack();else super.onBackPressed();}
}