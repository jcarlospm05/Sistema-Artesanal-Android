const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const file=path.join(__dirname,'../android-bobc-07/app/src/main/assets/www/bobc08_sync.js');
const empty=()=>({schema:1,created:'2026-10-15T00:00Z',settings:{company_name:'BOBC'},products:[],recipes:[],skus:[],quotes:[],invoices:[],payments:[],documents:[],calculations:[],inventory:[],movements:[],supplies:[],supplyMovements:[],packagingLinks:[],expenses:[],drafts:[],auditLog:[]});
let snapshot=null,revision=0;
function device(role){let current=empty(),backups=[],messages=[];const context={console,window:{},navigator:{onLine:true},document:{hidden:false,querySelector:()=>false,activeElement:null,addEventListener:()=>{}},setInterval:()=>1,clearInterval:()=>{},crypto:require('node:crypto').webcrypto,structuredClone,Error,JSON};
context.window.BOBCAuth={businessId:'business-1',member:{role},rpc:async(action,payload)=>{
 if(action==='bobc_sync_pull')return {revision,state:structuredClone(snapshot)};
 if(action==='bobc_sync_commit'){
  if(revision!==payload.p_revision)throw Error('CONFLICTO_REVISION');
  if(!snapshot&&role!=='admin')throw Error('Solo admin');
  snapshot=structuredClone(payload.p_state);revision++;return {revision};
 }
 throw Error(action)} };
context.window.addEventListener=()=>{};vm.createContext(context);vm.runInContext(fs.readFileSync(file,'utf8'),context);
const sync=context.window.BOBCSync;const handlers={fresh:empty,setState:x=>current=x,saveLocal:async x=>{current=x},saveMigrationBackup:async x=>backups.push(['migration',x]),saveConflict:async x=>backups.push(['conflict',x]),refresh:()=>{},warning:x=>messages.push(x),status:()=>{}};
return {sync,handlers,backups,messages,get current(){return current},get online(){return context.navigator.onLine},set online(x){context.navigator.onLine=x}}}
(async()=>{
 const a=device('admin'),b=device('operator');await a.sync.start(a.handlers,a.current);assert.equal(revision,1);assert.equal(a.backups.length,1);
 await b.sync.start(b.handlers,b.current);assert.equal(b.sync.revision,1);
 let next=structuredClone(a.current);next.products.push({id:'p1',name:'Ponche'});await a.sync.save(next);assert.equal(revision,2);
 const updated=await b.sync.refresh();assert.equal(updated,true);assert.equal(b.current.products.length,1);
 next=structuredClone(b.current);next.products.push({id:'p2',name:'Galletas'});await b.sync.save(next);assert.equal(revision,3);
 let stale=structuredClone(a.current);stale.products.push({id:'p3',name:'Conflict'});
 await assert.rejects(()=>a.sync.save(stale),/CONFLICTO_REVISION/);assert.equal(a.backups.at(-1)[0],'conflict');assert.equal(revision,3);
 await a.sync.refresh();assert.equal(a.current.products.length,2);
 a.online=false;await assert.rejects(()=>a.sync.save({...a.current,settings:{company_name:'Offline'}}),/internet/);a.online=true;
 console.log('PASS sync test: bootstrap, two-user pull, optimistic CAS, preserved conflict, offline blocked');
})().catch(e=>{console.error(e);process.exit(1)});