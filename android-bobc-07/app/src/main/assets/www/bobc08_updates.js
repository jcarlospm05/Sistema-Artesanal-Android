/* BOBC Update Manager: notifica nuevas APK oficiales; Android confirma su instalacion. */
'use strict';
window.BOBCUpdates=(()=>{
 const OWNER='jcarlospm05', REPO='Sistema-Artesanal-Android';
 const CURRENT=83, API='https://api.github.com/repos/'+OWNER+'/'+REPO+'/releases/latest';
 let checked=false;
 function code(tag){
   const m=String(tag||'').match(/^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/i);
   return m ? (+m[1]*10000 + +m[2]*100 + +m[3]) : null;
 }
 async function check(force=false){
   if(checked&&!force)return;
   checked=true;
   try{
     const response=await fetch(API,{headers:{Accept:'application/vnd.github+json'},cache:'no-store'});
     if(response.status===404)return; // No hay release estable publicada.
     if(!response.ok)throw Error('No se pudo consultar la version');
     const release=await response.json();
     if(release.draft || release.prerelease || (code(release.tag_name)??0)<=code('0.8.3'))return;
     const asset=(release.assets||[]).find(a=>/\.apk$/i.test(a.name||''));
     const url=asset?.browser_download_url;
     if(!url || !/^https:\/\/github\.com\/jcarlospm05\/Sistema-Artesanal-Android\/releases\/download\//.test(url))return;
     const existing=document.getElementById('bobc-update-notice');
     if(existing)return;
     const el=document.createElement('aside');el.id='bobc-update-notice';
     el.setAttribute('role','status');
     el.style.cssText='position:fixed;z-index:99999;bottom:12px;left:12px;right:12px;background:#fff;color:#242424;padding:16px;border:2px solid #6750a4;border-radius:12px;box-shadow:0 5px 25px #0004;font:14px sans-serif';
     const title=document.createElement('strong');title.textContent='Actualización BOBC '+release.tag_name+' disponible';
     const p=document.createElement('p');p.textContent='Antes de actualizar, realiza un respaldo. Android solicitará confirmar la actualización del APK. No desinstales BOBC.';
     const a=document.createElement('a');a.textContent='Descargar actualización';a.href=url;a.target='_blank';a.rel='noopener noreferrer';
     a.style.cssText='display:inline-block;padding:10px;background:#6750a4;color:white;border-radius:7px;margin-right:8px';
     const later=document.createElement('button');later.type='button';later.textContent='Más tarde';later.onclick=()=>el.remove();
     el.append(title,p,a,later);document.body.append(el);
   }catch(e){if(force)console.warn('BOBC Update Manager:',e.message);}
 }
 document.addEventListener('DOMContentLoaded',()=>setTimeout(()=>check(),4000));
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)check(true)});
 return {check,currentVersion:'0.8.3-sync-beta',currentVersionCode:CURRENT};
})();
