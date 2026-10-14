const AREAS={
'Proyectos':['projects','project_phases','project_tasks','project_milestones','project_deliverables'],
'Contratos':['contracts','contract_parties','contract_terms','contract_revisions','contract_renewals'],
'Cuentas por cobrar':['receivables','receivable_installments','receivable_payments','payment_allocations','collection_followups'],
'Gastos':['expense_categories','expenses','expense_items','expense_attachments'],
'Formularios':['form_submissions','form_answers','form_rules'],
'Presupuestos':['budgets','budget_lines','budget_versions','budget_actuals'],
'Inventario':['warehouses','inventory_items','inventory_lots','inventory_movements','stock_counts','stock_count_lines'],
'Proveedores':['suppliers','purchase_orders','purchase_order_lines','supplier_contacts','supplier_prices']
};
const LABEL={projects:'Proyectos',contracts:'Contratos',receivables:'Cuentas',expenses:'Gastos',budgets:'Presupuestos',warehouses:'Almacenes',inventory_items:'Artículos',inventory_movements:'Movimientos',suppliers:'Proveedores',purchase_orders:'Órdenes de compra'};
const safe=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const title=s=>LABEL[s]||s.replaceAll('_',' ').replace(/^./,c=>c.toUpperCase());
export class ModuleManager{
 constructor(root,repo,schema,notify){this.root=root;this.repo=repo;this.schema=schema;this.notify=notify;this.area='Proyectos';this.entity='projects'}
 async open(){this.root.hidden=false;await this.draw()}
 async draw(){const areaNames=Object.keys(AREAS);
 this.root.innerHTML='<h2>Módulos v0.4</h2><p>Altas y consultas de registros vinculados. Los cálculos financieros automáticos aún están en desarrollo.</p>'+
 '<label>Área<select id="crm-area">'+areaNames.map(a=>'<option '+(a===this.area?'selected':'')+'>'+safe(a)+'</option>').join('')+'</select></label>'+
 '<label>Entidad<select id="crm-entity">'+AREAS[this.area].map(e=>'<option value="'+e+'" '+(e===this.entity?'selected':'')+'>'+safe(title(e))+'</option>').join('')+'</select></label>'+
 '<div id="crm-module-rows"></div><form id="crm-module-form"><h3>Nuevo registro: '+safe(title(this.entity))+'</h3><div id="crm-fields"></div><button type="submit">Guardar registro</button></form>';
 this.root.querySelector('#crm-area').onchange=async e=>{this.area=e.target.value;this.entity=AREAS[this.area][0];await this.draw()};
 this.root.querySelector('#crm-entity').onchange=async e=>{this.entity=e.target.value;await this.draw()};
 const spec=this.schema[this.entity],fields=this.root.querySelector('#crm-fields');
 for(const [key,type] of Object.entries(spec.fields)){
 if(['id','created_at','updated_at'].includes(key))continue;
 const label=document.createElement('label');label.textContent=title(key);label.style.display='block';label.style.margin='12px 0';
 let input;
 if(spec.references?.[key]){
 input=document.createElement('select');input.name=key;input.appendChild(new Option('Sin vincular',''));
 const target=spec.references[key].split('.')[0],records=await this.repo.all(target);
 for(const r of records){const name=r.display_name||r.name||r.title||r.contract_number||r.order_number||r.supplier_code||r.sku||r.id.slice(0,8);input.appendChild(new Option(name,r.id))}
 }else if(type.startsWith('boolean')){input=document.createElement('input');input.type='checkbox';input.name=key}
 else{input=document.createElement('input');input.name=key;
 input.type=key.endsWith('_minor')||['quantity','sort_order','version_number','expected_quantity','counted_quantity'].includes(key)?'number':'text';
 if(input.type==='number'){input.step=key.includes('quantity')?'0.01':'1';input.min='0'}
 if(key.endsWith('_date')||key.endsWith('_at'))input.placeholder='AAAA-MM-DD o fecha ISO';
 }
 input.className='crm-field';input.style.cssText='width:100%;padding:12px;border:1px solid #cad5d7;border-radius:10px;margin-top:5px';
 label.appendChild(input);fields.appendChild(label);
 }
 this.root.querySelector('#crm-module-form').onsubmit=async e=>{
 e.preventDefault();const record={};for(const inp of e.target.querySelectorAll('[name]')){
 if(inp.type==='checkbox')record[inp.name]=inp.checked;
 else if(inp.value.trim()!=='')record[inp.name]=inp.type==='number'?Number(inp.value):inp.value.trim();
 }
 if(!Object.values(record).some(v=>v!==false)){this.notify('Completa algún campo');return}
 try{await this.repo.save(this.entity,record);this.notify('Registro guardado en '+title(this.entity));await this.draw()}catch(err){this.notify('No se guardó: '+err.message)}
 };
 const rows=await this.repo.all(this.entity);
 this.root.querySelector('#crm-module-rows').innerHTML='<div class="record"><div><b>'+rows.length+' registros</b><small>'+safe(title(this.entity))+'</small></div></div>'+
 rows.slice().reverse().slice(0,30).map(r=>'<div class="record"><div><b>'+safe(r.name||r.title||r.contract_number||r.order_number||r.sku||r.supplier_code||r.description||r.id.slice(0,8))+'</b><small>'+safe(r.status||r.created_at?.slice(0,10)||'')+'</small></div></div>').join('');
 }
 close(){this.root.hidden=true}
}
export const MODULE_AREAS=AREAS;