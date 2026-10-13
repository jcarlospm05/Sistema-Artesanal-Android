/* BOBC v0.7 - Navigation drawer: no artificial user login or logout */
'use strict';
window.BOBCMenu7=(()=>{
 const sections=[
  ['GENERAL',[['dashboard','Inicio','home'],['invoices','Ventas y facturación','sales'],['quotes','Cotizaciones','file'],['inventory','Inventario','package']]],
  ['PRODUCCIÓN',[['catalog','Productos y fórmulas','bottle'],['calculator','Cocina A','calculator'],['costs','Costos B','chart']]],
  ['GESTIÓN',[['expenses','Gastos y compras','expenses'],['documents','Documentos','file'],['settings','Negocio','store'],['preferences','Configuración y respaldos','settings']]]
 ];
 const labels={dashboard:'Inicio',invoices:'Ventas y facturación',quotes:'Cotizaciones',catalog:'Productos y fórmulas',inventory:'Inventario',calculator:'Cocina A',costs:'Costos B',expenses:'Gastos y compras',documents:'Documentos',settings:'Negocio',preferences:'Configuración'};
 let opened=false;
 function render(route){
  const header=document.querySelector('header');if(!header)return;
  const current=route||'dashboard',label=labels[current]||'BOBC';
  header.innerHTML=`<button id="menuBtn" type="button" class="main-menu-btn" aria-label="Abrir menú principal" aria-expanded="${opened}" aria-controls="mainDrawer"><svg class="ui-icon" width="25" height="25" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg></button><div class="headtext"><b>BOBC <span class="top-version">v0.7</span></b><small>${label} · Taller Artesanal</small></div><span class="offline" id="net">Datos en el celular</span>`;
  const root=document.querySelector('#menuRoot');if(!root)return;
  root.innerHTML=`<button type="button" class="drawer-scrim" data-menu-close aria-label="Cerrar menú principal" tabindex="-1"></button><aside id="mainDrawer" class="main-drawer" aria-label="Menú principal" aria-hidden="${!opened}"><div class="drawer-head"><div class="drawer-brand"><span class="drawer-brand-icon"><svg width="31" height="31" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M9 2h6v5l2 3v11H7V10l2-3V2M9 7h6M7 14h10"/></svg></span><span><b>BOBC</b><small>TALLER ARTESANAL · v0.7</small></span></div><button class="drawer-close" type="button" data-menu-close aria-label="Cerrar menú"><svg width="22" height="22" viewBox="0 0 24 24" stroke="currentColor" fill="none" stroke-width="1.8"><path d="M5 5 19 19M19 5 5 19"/></svg></button></div><nav class="drawer-list">${sections.map(([heading,links])=>`<div class="drawer-section"><div class="drawer-section-title">${heading}</div>${links.map(([id,name,icon])=>`<button type="button" data-nav="${id}" class="drawer-link ${id===current?'is-active':''}" ${id===current?'aria-current="page"':''}><span class="drawer-link-icon">${window.BOBCUI6.ico(icon,22)}</span><span>${name}</span></button>`).join('')}</div>`).join('')}</nav><div class="drawer-footer">Tus registros permanecen en este dispositivo. Usa <b>Configuración y respaldos</b> para exportarlos.</div></aside>`;
  document.body.classList.toggle('drawer-open',opened);
 }
 function open(){if(opened)return;opened=true;document.body.classList.add('drawer-open');const btn=document.querySelector('#menuBtn');btn?.setAttribute('aria-expanded','true');const drawer=document.querySelector('#mainDrawer');drawer?.setAttribute('aria-hidden','false');drawer?.querySelector('[data-nav]')?.focus();}
 function close(){if(!opened)return;opened=false;document.body.classList.remove('drawer-open');document.querySelector('#menuBtn')?.setAttribute('aria-expanded','false');document.querySelector('#mainDrawer')?.setAttribute('aria-hidden','true');document.querySelector('#menuBtn')?.focus();}
 function toggle(){opened?close():open()}
 return {render,open,close,toggle,labels};
})();