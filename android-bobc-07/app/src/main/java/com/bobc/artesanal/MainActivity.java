package com.bobc.artesanal;

import android.app.Activity;
import android.print.PrintManager;
import android.content.ActivityNotFoundException;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.core.content.FileProvider;
import androidx.webkit.WebViewAssetLoader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

/** BOBC 0.7.1 — Aplicación autónoma, sin servidor ni conexión obligatoria. */
public class MainActivity extends Activity {
    private static final String APP_ORIGIN = "https://appassets.androidplatform.net";
    private static final String INDEX_URL = APP_ORIGIN + "/assets/www/index.html";
    private static final int FILE_REQUEST = 1107;
    private WebView webView;
    private ValueCallback<Uri[]> pendingFileChooser;

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(android.graphics.Color.rgb(255,166,158));
        getWindow().setNavigationBarColor(android.graphics.Color.rgb(250,243,221));

        WebViewAssetLoader assetLoader = new WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
            .build();
        webView = new WebView(this);
        webView.setBackgroundColor(android.graphics.Color.rgb(247,245,252));
        webView.setVerticalScrollBarEnabled(false);
        WebSettings cfg = webView.getSettings();
        cfg.setJavaScriptEnabled(true);
        cfg.setDomStorageEnabled(true);
        cfg.setDatabaseEnabled(true);
        cfg.setAllowFileAccess(false);
        cfg.setAllowContentAccess(true);
        cfg.setJavaScriptCanOpenWindowsAutomatically(false);
        cfg.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        cfg.setMediaPlaybackRequiresUserGesture(true);

        webView.addJavascriptInterface(new DeviceBridge(), "BOBCAndroid");
        webView.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (APP_ORIGIN.equals(uri.getScheme() + "://" + uri.getAuthority())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
                catch (Exception ignored) { showToast("No se pudo abrir el enlace externo"); }
                return true;
            }
        });
        webView.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (pendingFileChooser != null) pendingFileChooser.onReceiveValue(null);
                pendingFileChooser = callback;
                try {
                    Intent choose = params.createIntent();
                    startActivityForResult(choose, FILE_REQUEST);
                    return true;
                } catch (ActivityNotFoundException e) {
                    pendingFileChooser = null;
                    showToast("No se encontró una aplicación para seleccionar archivos");
                    return false;
                }
            }
        });
        setContentView(webView);
        webView.loadUrl(INDEX_URL);
    }

    @Override @SuppressWarnings("deprecation")
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_REQUEST && pendingFileChooser != null) {
            Uri[] selected = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
            pendingFileChooser.onReceiveValue(selected);
            pendingFileChooser = null;
        }
    }

    private String safeName(String requested) {
        String name = (requested == null ? "BOBC-documento" : requested)
            .replaceAll("[^\\p{L}\\p{N}._-]", "_");
        return name.length() > 110 ? name.substring(name.length()-110) : name;
    }
    private void showToast(String msg) {
        runOnUiThread(() -> Toast.makeText(this,msg,Toast.LENGTH_LONG).show());
    }
    private Uri writeDownloads(String name, String mime, byte[] bytes) throws Exception {
        String filename = safeName(name);
        if (Build.VERSION.SDK_INT >= 29) {
            ContentValues row = new ContentValues();
            row.put(MediaStore.Downloads.DISPLAY_NAME, filename);
            row.put(MediaStore.Downloads.MIME_TYPE, mime);
            row.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/BOBC/");
            Uri uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,row);
            if (uri == null) throw new Exception("No se pudo crear el archivo en Descargas");
            try (OutputStream out=getContentResolver().openOutputStream(uri)) {
                if(out==null)throw new Exception("Almacenamiento no disponible");
                out.write(bytes);
            }
            return uri;
        }
        File directory = new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),"BOBC");
        if (!directory.exists() && !directory.mkdirs()) throw new Exception("No se pudo crear la carpeta de salida");
        File file=new File(directory,filename);
        try (FileOutputStream out=new FileOutputStream(file)) {out.write(bytes);}
        return FileProvider.getUriForFile(this,getPackageName()+".fileprovider",file);
    }
    class DeviceBridge {
        @JavascriptInterface public void saveBase64(String name, String mime, String data) {
            try {
                byte[] binary = Base64.decode(data, Base64.DEFAULT);
                writeDownloads(name,mime,binary);
                showToast("Guardado en Descargas / BOBC: " + safeName(name));
            } catch (Exception e) { showToast("Error al guardar: "+e.getMessage()); }
        }
        @JavascriptInterface public void shareBase64(String name, String mime, String data) {
            try {
                byte[] binary = Base64.decode(data, Base64.DEFAULT);
                File folder = new File(getCacheDir(),"shared");
                if (!folder.exists() && !folder.mkdirs()) throw new Exception("No se creó la carpeta temporal");
                File file = new File(folder,safeName(name));
                try (FileOutputStream out = new FileOutputStream(file)) {out.write(binary);}
                Uri uri=FileProvider.getUriForFile(MainActivity.this,getPackageName()+".fileprovider",file);
                runOnUiThread(() -> {
                    Intent send=new Intent(Intent.ACTION_SEND);
                    send.setType(mime);
                    send.putExtra(Intent.EXTRA_STREAM,uri);
                    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(Intent.createChooser(send,"Compartir comprobante BOBC"));
                });
            } catch (Exception e) {showToast("Error al compartir: "+e.getMessage());}
        }
        @JavascriptInterface public void printPage() {
            runOnUiThread(() -> {
                PrintManager manager=(PrintManager)getSystemService(Context.PRINT_SERVICE);
                manager.print("Documento BOBC",webView.createPrintDocumentAdapter("BOBC"),null);
            });
        }
    }
    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack(); else super.onBackPressed();
    }
    @Override public void onDestroy() {
        if(webView!=null){webView.removeJavascriptInterface("BOBCAndroid");webView.destroy();webView=null;}
        super.onDestroy();
    }
}