/* BOBC 0.8 - Usuarios Supabase Auth. No contiene credenciales privilegiadas. */
'use strict';
window.BOBCAuth=(()=>{
const cfg=window.BOBC_SUPABASE||{}, STORAGE='bobc08_auth_session_v1';
const profiles={
 admin:{label:'Administrador',users:1,quotes:1,invoices:1,payments:1,delivery:1,inventory:1,production:1,reports:1,void:1},
 sales:{label:'Operador comercial y producción',users:0,quotes:0,invoices:1,payments:1,delivery:1,inventory:1,production:1,reports:1,void:0},
 production:{label:'Producción e inventario',users:0,quotes:0,invoices:0,payments:0,delivery:0,inventory:1,production:1,reports:1,void:0},
 viewer:{label:'Solo consulta',users:0,quotes:0,invoices:0,payments:0,delivery:0,inventory:0,production:0,reports:1,void:0}
};
let session=null,member=null,processing=false;
const esc=x=>String(x||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','"':'&quot;'}[c]));
const api=String(cfg.url||'').replace(/\/$/,'');
function authRoot(){return document.getElementById('authRoot')}
function show(message='',register=false){
 document.getElementById('app').hidden=true;const root=authRoot();root.hidden=false;
 root.innerHTML=`<main class="auth-shell"><div class="auth-box"><div class="auth-brand"><b>BOBC</b><small>TALLER ARTESANAL · PRIVADO</small></div><h2>${register?'Activar mi acceso':'Iniciar sesión'}</h2><p class="sub">${register?'Solo cuentas previamente autorizadas por el administrador podrán acceder al negocio.':'Ingresa con tu cuenta personal de BOBC.'}</p><form id="bobcAuthForm" data-register="${register?'yes':'no'}"><label class="field">Correo electrónico<input name="email" type="email" autocomplete="email" required></label><label class="field">Contraseña<input name="password" type="password" autocomplete="${register?'new-password':'current-password'}" minlength="8" required></label><button class="btn" type="submit">${register?'Crear contraseña y verificar correo':'Entrar a BOBC'}</button></form><button class="btn secondary" type="button" data-bobc-auth-toggle="${register?'login':'register'}">${register?'Ya tengo una cuenta':'Tengo una invitación: activar cuenta'}</button>${message?`<div class="note" role="status">${esc(message)}</div>`:''}<p class="sub">La cuenta y sus permisos se verifican en Supabase. Las ventas de esta Preview todavía se guardan localmente.</p></div></main>`;
}
function setSession(x){session=x;try{if(x)localStorage.setItem(STORAGE,JSON.stringify(x));else localStorage.removeItem(STORAGE)}catch(_){}}
function clear(){setSession(null);member=null}
async function call(path,body,token=null,method='POST'){
 if(!api||!cfg.publishableKey)throw Error('Falta configuración de Supabase en esta instalación');
 const headers={'apikey':cfg.publishableKey,'Content-Type':'application/json'};
 if(token)headers.Authorization='Bearer '+token;
 const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),18000);
 try{const response=await fetch(api+path,{method,headers,body:method==='GET'?undefined:JSON.stringify(body||{}),signal:controller.signal});
 const data=await response.json().catch(()=>null);
 if(!response.ok)throw Error(data?.msg||data?.error_description||data?.message||data?.error||`Error de servidor (${response.status})`);
 return data;
 }finally{clearTimeout(timeout)}
}
async function refreshSession(){if(!session?.refresh_token)throw Error('Inicia sesión');const data=await call('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token});setSession({...data,expire_at:Date.now()+data.expires_in*1000});}
async function ensureSession(){if(!session)throw Error('Inicia sesión');if(!session.access_token||!session.expire_at||session.expire_at<Date.now()+60000)await refreshSession();}
async function rpc(name,payload={}){await ensureSession();return call('/rest/v1/rpc/'+name,payload,session.access_token)}
async function get(path){await ensureSession();return call('/rest/v1/'+path,null,session.access_token,'GET')}
async function validate(){await ensureSession();await call('/auth/v1/user',null,session.access_token,'GET');const rows=await rpc('bobc_claim_invitation');member=Array.isArray(rows)?rows[0]:null;
 if(!member)throw Error('Este correo aún no tiene una invitación autorizada por el administrador.');return true;}
async function init(){
 show('Conectando de forma segura…');
 try{session=JSON.parse(localStorage.getItem(STORAGE)||'null')}catch(_){session=null}
 if(!session){show();return false}
 try{await validate();authRoot().hidden=true;document.getElementById('app').hidden=false;return true}
 catch(e){clear();show(e.message);return false}
}
async function login(email,password){const data=await call('/auth/v1/token?grant_type=password',{email,password});setSession({...data,expire_at:Date.now()+data.expires_in*1000});try{await validate();location.reload()}catch(e){clear();show(e.message)}}
async function signup(email,password){await call('/auth/v1/signup',{email,password});show('Revisa tu correo y confirma el registro. Luego vuelve a BOBC y utiliza Iniciar sesión. Si no tienes una invitación del administrador, no se activará el acceso.');}
function bind(){document.addEventListener('click',e=>{const b=e.target.closest('[data-bobc-auth-toggle]');if(b){show('',b.dataset.bobcAuthToggle==='register');return}
 const out=e.target.closest('[data-bobc-logout]');if(out){logout();return}});
 document.addEventListener('submit',async e=>{if(e.target.id!=='bobcAuthForm')return;e.preventDefault();if(processing)return;processing=true;
 const form=e.target,register=form.dataset.register==='yes',email=form.elements.email.value.trim().toLowerCase(),password=form.elements.password.value;
 try{show('Procesando…',register);if(register)await signup(email,password);else await login(email,password)}catch(err){show(err.message,register)}finally{processing=false}
 });}
async function logout(){try{if(session?.access_token)await call('/auth/v1/logout',{},session.access_token)}catch(_){}clear();location.reload()}
function allowed(permission){return !!(member&&profiles[member.profile_key]?.[permission])}
function canRoute(route){if(!member)return false;
 if(route==='users'||route==='preferences'||route==='settings')return allowed('users');
 if(['calculator','costs','catalog'].includes(route))return allowed('production')||allowed('users')||member.profile_key==='viewer';
 if(route==='inventory')return allowed('inventory')||member.profile_key==='viewer';
 if(['invoices','quotes'].includes(route))return allowed('invoices')||member.profile_key==='viewer';
 if(route==='expenses')return true; // Consulta para operador; registrar gasto requiere ser administrador.
 return true;}
function writable(kind){if(!member||member.profile_key==='viewer')return false;return allowed(kind)}
return {bind,init,login,signup,rpc,get,allowed,canRoute,writable,logout,profiles,get member(){return member},get businessId(){return member?.business_id||''}};
})();