export const DB_NAME='bobc-crm';export const DB_VERSION=2;
export async function loadSchema(){
 const urls=['./data/schema.json','./data/schema-extension-v2.json'];
 const values=await Promise.all(urls.map(async url=>{const r=await fetch(url,{cache:'no-store'});if(!r.ok)throw Error('No disponible: '+url);return r.json()}));
 if(values[0].entities.length!==51||values[1].entities.length!==45)throw Error('La versión del esquema no coincide');
 const all=[...values[0].entities,...values[1].entities];
 const names=new Set(all.map(e=>e.entity));if(names.size!==96)throw Error('Nombres de entidades duplicados');
 for(const e of all)for(const target of Object.values(e.references||{}))if(!names.has(target.split('.')[0]))throw Error('Referencia inexistente '+e.entity+' → '+target);
 return Object.fromEntries(all.map(e=>[e.entity,e]));
}