/* BOBC 0.8 - Multi-dispositivo. PostgreSQL = fuente de verdad.
   Client performs optimistic revision check; server executes transaction, RLS, roles and integrity checks.
   Offline: reading cached only. NO financial changes while offline. */
'use strict';
window.BOBCSync=(()=>{
let revision=0,ready=false,working=false,lastAccepted=null,locked=false,businessId='',refreshHandle=null;
let callbacks={};
const clone=x=>structuredClone(x);
const canSync=()=>ready && !!businessId;
const validState=x=>x&&x.schema===1&&Array.isArray(x.invoices)&&Array.isArray(x.products);
const warn=x=>{callbacks.warning?.(x);console.warn('[BOBC sync]',x)};
async function pull(){
 if(!businessId)throw Error('Inicia sesión en BOBC');
 const response=await window.BOBCAuth.rpc('bobc_sync_pull',{p_business_id:businessId});
 if(!response||typeof response.revision!=='number')throw Error('Respuesta inesperada de Supabase');
 return response;
}
async function setLocal(x,doRender){
 callbacks.setState(clone(x));
 await callbacks.saveLocal(clone(x));
 if(doRender)callbacks.refresh?.();
}
async function commit(state,opId=crypto.randomUUID()){
 if(working)throw Error('Ya se está guardando una operación. Reintenta.');
 if(!navigator.onLine)throw Error('Se necesita internet para registrar operaciones y evitar duplicados.');
 working=true;
 const copy=clone(state);
 try{
  const result=await window.BOBCAuth.rpc('bobc_sync_commit',{p_business_id:businessId,p_revision:revision,p_state:copy,p_operation_id:opId});
  if(!Number.isInteger(result?.revision))throw Error('Supabase no confirmó el guardado');
  revision=result.revision;lastAccepted=copy;
  await callbacks.saveLocal(copy);
  callbacks.status?.('Sincronizado');
  return result;
 }catch(e){
  // Local changes are discarded ONLY after being saved to a recoverable conflict copy.
  try{await callbacks.saveConflict(copy)}catch(_){}
  if(lastAccepted)await setLocal(lastAccepted,true);
  callbacks.status?.('Pendiente / error');
  warn('No se guardó la operación: '+e.message+'. Se preservó copia para recuperación.');
  throw e;
 }finally{working=false}
}
async function initial(local){
 businessId=window.BOBCAuth.businessId;
 if(!businessId)throw Error('No hay un negocio asignado a este usuario');
 const server=await pull();
 revision=server.revision;
 if(validState(server.state)){
  lastAccepted=clone(server.state);ready=true;
  await setLocal(lastAccepted,false);
  callbacks.status?.('Sincronizado');
  return {mode:'cloud',revision};
 }
 if(server.state!==null)throw Error('La base remota no tiene formato compatible con BOBC. No se tocaron los datos locales.');
 // Primer dispositivo autorizado crea la base común. Solo admin puede hacerlo.
 if(window.BOBCAuth.member?.role!=='admin'){
  ready=false;callbacks.status?.('Esperando base del administrador');
  throw Error('La base compartida debe inicializarse primero desde el teléfono administrador');
 }
 ready=true;revision=0;
 const initialState=validState(local)?clone(local):callbacks.fresh();
 // Respaldo local anterior siempre antes de migrar al backend.
 await callbacks.saveMigrationBackup(clone(initialState));
 const uploaded=await commit(initialState);
 callbacks.status?.('Sincronizado');
 return {mode:'seeded',revision:uploaded.revision};
}
async function refresh(){
 if(!canSync()||working||locked||!navigator.onLine)return false;
 working=true;
 try{
  const p=await pull();
  if(p.revision<=revision)return false;
  if(!validState(p.state))throw Error('Datos remotos inválidos, no sobrescribiré el celular');
  revision=p.revision;lastAccepted=clone(p.state);
  await setLocal(lastAccepted,true);
  callbacks.status?.('Sincronizado');return true;
 }catch(e){callbacks.status?.('Sin conexión');warn('No se pudo actualizar: '+e.message);return false}
 finally{working=false}
}
function schedule(){if(refreshHandle)clearInterval(refreshHandle);
 refreshHandle=setInterval(()=>{
  if(document.hidden||document.querySelector('.sheet-open')||document.activeElement?.matches('input,textarea,select'))return;
  refresh();
 },10000);
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh()});
 window.addEventListener('online',()=>refresh());
}
async function start(cb,local){callbacks=cb;const r=await initial(local);schedule();return r}
async function save(state){if(!canSync())throw Error('No está conectada la base compartida');
 if(lastAccepted&&JSON.stringify(state)===JSON.stringify(lastAccepted))return {revision,unchanged:true};
 return commit(state);
}
async function restoreFresh(){const p=await pull();
 if(validState(p.state)){revision=p.revision;lastAccepted=clone(p.state);ready=true;await setLocal(lastAccepted,true)}
}
function pause(){locked=true}function resume(){locked=false}
return {start,save,refresh,restoreFresh,pause,resume,get enabled(){return canSync()},get busy(){return working},get revision(){return revision}};
})();