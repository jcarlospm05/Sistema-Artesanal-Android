'use strict';
(function(){
 if(!window.SQLiteBridge){
   window.ArtesanalMobileError='Esta es la versión Android. Instala el APK; no abras index.html en el navegador para registrar ventas.';
   window.localAPI={execute:()=>{throw Error(window.ArtesanalMobileError)}};
   return;
 }
 window.localAPI=window.ArtesanalRepository.make({execute:payload=>window.SQLiteBridge.execute(payload)});
 window.nativeNotice=message=>{const el=document.querySelector('#toast');if(el){el.className='status active good';el.textContent=String(message);}}
 window.mobileBackup=function(path){
   if(path.endsWith('sqlite'))return window.AndroidFiles.exportPackage();
   const contents=JSON.stringify(window.localAPI.backupJson());
   window.AndroidFiles.saveJson('Respaldo_Sistema_Artesanal_'+new Date().toISOString().slice(0,10)+'.json',contents);
 }
 window.mobileDocumentPNG=function(doc,canvas){window.AndroidFiles.savePng(doc.header.number+'.png',canvas.toDataURL('image/png').split(',')[1])};
 window.mobileSharePNG=function(doc,canvas){window.AndroidFiles.sharePng(doc.header.number+'.png',canvas.toDataURL('image/png').split(',')[1])};
})();