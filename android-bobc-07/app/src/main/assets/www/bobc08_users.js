/* BOBC 0.8 - Módulo de usuarios/perfiles. RPC Supabase aplica autorización real. */
'use strict';
window.BOBCUsers=(()=>{
let members=[],invites=[],busy=false,loaded=false,lastError='';
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','"':'&quot;'}[c]));
const pname=k=>window.BOBCAuth.profiles[k]?.label||k;
const choices=k=>Object.keys(window.BOBCAuth.profiles).filter(p=>p!=='admin').map(p=>`<option value="${p}" ${k===p?'selected':''}>${pname(p)}</option>`).join('');
function view(){if(!window.BOBCAuth.allowed('users'))return '<p>Acceso exclusivo para el administrador.</p>';
 return `<section class="app-page"><div class="section-head main-section"><h1>Usuarios y perfiles</h1><span>${members.length} usuario(s)</span></div><p class="sub">Autoriza quién puede utilizar BOBC y qué acciones podrá realizar. Solo tú puedes administrar usuarios.</p>
 <div class="simple-panel"><h2>Crear usuario</h2><form id="usersInviteForm"><label class="field">Nombre o identificación<input name="name" type="text" maxlength="100" required placeholder="Ej. Operador comercial"></label><label class="field">Correo electrónico<input name="email" type="email" required placeholder="usuario@correo.com"></label><label class="field">Perfil de acceso<select name="profile" required>${choices('sales')}</select></label><button class="btn" type="submit" ${busy?'disabled':''}>Autorizar usuario</button></form><p class="sub">La persona instalará BOBC, elegirá su propia contraseña y confirmará su correo. Los registros se sincronizarán automáticamente.</p></div>
 <div class="simple-panel"><h2>Perfiles disponibles</h2>${Object.entries(window.BOBCAuth.profiles).map(([key,p])=>`<div class="user-row"><b>${esc(pname(key))}</b><small>${key==='admin'?'Acceso total y control de usuarios':key==='sales'?'Crear facturas, convertir cotizaciones, registrar abonos y entregas, recetas e inventario. Sin anular ni editar documentos emitidos.':key==='production'?'Recetas, materiales y existencias':'Consultar sin modificar'}</small></div>`).join('')}</div>
 <div class="simple-panel"><h2>Usuarios activos y suspendidos</h2>${loaded?(members.map(m=>`<div class="user-row"><b>${esc(m.display_name||m.email||m.user_id)}</b><small>${esc(m.email)} · ${esc(pname(m.profile_key))} · ${m.active?'Activo':'Suspendido'}</small>${m.role==='operator'?`<div class="user-actions"><select id="profile-${esc(m.user_id)}" aria-label="Perfil de usuario">${choices(m.profile_key)}</select><button type="button" class="btn secondary small" data-bobc-user-save="${esc(m.user_id)}">Guardar perfil</button><button type="button" class="btn secondary small" data-bobc-user-toggle="${esc(m.user_id)}">${m.active?'Suspender':'Reactivar'}</button></div>`:'<small>Administrador principal · protegido</small>'}</div>`).join('')||'<p class="sub">Todavía no hay usuarios activados.</p>'):'<p class="sub">Cargando usuarios…</p>'}</div>
 <div class="simple-panel"><h2>Invitaciones pendientes</h2>${loaded?(invites.filter(x=>x.status==='pending').map(i=>`<div class="user-row"><b>${esc(i.display_name||i.email)}</b><small>${esc(i.email)} · ${esc(pname(i.profile_key))}</small>${i.role==='operator'?`<button type="button" class="btn secondary small" data-bobc-user-revoke="${esc(i.id)}">Cancelar invitación</button>`:''}</div>`).join('')||'<p class="sub">No hay invitaciones pendientes.</p>'):'<p class="sub">Cargando…</p>'}</div>
 ${lastError?`<p class="note">${esc(lastError)}</p>`:''}
 <div class="actions"><button class="btn secondary" type="button" data-bobc-user-refresh>Actualizar listado</button><button class="btn secondary" type="button" data-bobc-logout>Cerrar sesión</button></div></section>`;}
async function refresh(){if(!window.BOBCAuth.allowed('users'))return;try{
 const id=window.BOBCAuth.businessId,enc=encodeURIComponent('eq.'+id);
 const [m,i]=await Promise.all([window.BOBCAuth.get('memberships?select=user_id,email,display_name,role,profile_key,active&business_id='+enc),window.BOBCAuth.get('pending_invites?select=id,email,display_name,role,profile_key,status&business_id='+enc)]);
 members=Array.isArray(m)?m:[];invites=Array.isArray(i)?i:[];lastError='';loaded=true;
 }catch(e){lastError='No se pudo cargar el listado: '+e.message;loaded=true}
 if(window.BOBCRefreshUsers)window.BOBCRefreshUsers();}
async function submit(form){if(form.id!=='usersInviteForm')return false;if(!window.BOBCAuth.allowed('users'))throw Error('Sin permiso para crear usuarios');
 if(busy)return true;busy=true;try{
 const mail=form.elements.email.value.trim().toLowerCase(),name=form.elements.name.value.trim(),profile=form.elements.profile.value;
 await window.BOBCAuth.rpc('bobc_invite_user',{p_business_id:window.BOBCAuth.businessId,p_email:mail,p_profile_key:profile,p_name:name});
 form.reset();await refresh();alert('Usuario autorizado. Comparte con esa persona la APK para que active su cuenta con este mismo correo.');
 }finally{busy=false}return true;}
async function click(btn){if(!window.BOBCAuth.allowed('users'))return false;
 if(btn.hasAttribute('data-bobc-user-refresh')){await refresh();return true}
 if(btn.hasAttribute('data-bobc-user-revoke')){if(!confirm('¿Cancelar esta invitación?'))return true;
 await window.BOBCAuth.rpc('bobc_revoke_invitation',{p_business_id:window.BOBCAuth.businessId,p_invitation_id:btn.dataset.bobcUserRevoke});await refresh();return true}
 const id=btn.dataset.bobcUserSave||btn.dataset.bobcUserToggle;
 if(id){const m=members.find(x=>x.user_id===id);if(!m)throw Error('Usuario no encontrado');const profile=document.getElementById('profile-'+id)?.value||m.profile_key;
 const active=btn.hasAttribute('data-bobc-user-toggle')?!m.active:m.active;
 if(!active&&!confirm('¿Suspender el acceso de este usuario?'))return true;
 await window.BOBCAuth.rpc('bobc_update_user',{p_business_id:window.BOBCAuth.businessId,p_user_id:id,p_profile_key:profile,p_active:active});await refresh();return true;
 }
 return false;}
return {view,refresh,click,submit};
})();