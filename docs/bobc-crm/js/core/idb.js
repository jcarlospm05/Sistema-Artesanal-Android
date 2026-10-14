import {DB_NAME,DB_VERSION} from './schema.js';
export const requestResult=req=>new Promise((resolve,reject)=>{req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error)});
export const transactionFinished=tx=>new Promise((resolve,reject)=>{tx.oncomplete=()=>resolve();tx.onabort=()=>reject(tx.error||Error('Transacción cancelada'));tx.onerror=()=>reject(tx.error||Error('Transacción fallida'))});
export function openDatabase(entities){return new Promise((resolve,reject)=>{
 const q=indexedDB.open(DB_NAME,DB_VERSION);q.onupgradeneeded=event=>{const db=q.result,tx=q.transaction;
 if(event.oldVersion>2){tx.abort();return;}
 for(const [name,entity] of Object.entries(entities)){
 const s=db.objectStoreNames.contains(name)?tx.objectStore(name):db.createObjectStore(name,{keyPath:'id'});
 for(const k of new Set([...Object.keys(entity.references||{}),'created_at','updated_at']))if(k!=='id'&&!s.indexNames.contains(k))s.createIndex(k,k);
 }};
 q.onblocked=()=>reject(Error('Cierra otras pestañas del CRM y vuelve a intentar'));
 q.onerror=()=>reject(q.error);q.onsuccess=()=>{q.result.onversionchange=()=>q.result.close();resolve(q.result)};
})}
export const readOne=(db,t,id)=>requestResult(db.transaction(t,'readonly').objectStore(t).get(id));
export const readAll=(db,t)=>requestResult(db.transaction(t,'readonly').objectStore(t).getAll());