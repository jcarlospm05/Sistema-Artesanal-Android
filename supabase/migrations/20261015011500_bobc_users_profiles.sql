-- BOBC 0.8: usuarios y perfiles (creación autorizada desde la app)
-- Evitar contraseñas almacenadas por BOBC. Supabase Auth valida identidad y email.
create table public.access_profiles (
  profile_key text primary key check (profile_key in ('admin','sales','production','viewer')),
  display_name text not null,
  description text not null,
  permissions jsonb not null check(jsonb_typeof(permissions)='object'),
  sort_order int not null
);
insert into public.access_profiles(profile_key,display_name,description,permissions,sort_order) values
('admin','Administrador','Configuración, usuarios y operaciones comerciales.', '{"users":true,"quotes":true,"invoices":true,"payments":true,"delivery":true,"inventory":true,"production":true,"reports":true,"void":true}',0),
('sales','Operador comercial','Cotizaciones, facturación, abonos, cobros y entregas.', '{"users":false,"quotes":true,"invoices":true,"payments":true,"delivery":true,"inventory":false,"production":false,"reports":true,"void":false}',1),
('production','Producción e inventario','Fórmulas, costos, insumos e inventario.', '{"users":false,"quotes":false,"invoices":false,"payments":false,"delivery":false,"inventory":true,"production":true,"reports":true,"void":false}',2),
('viewer','Solo consulta','Puede consultar información sin modificarla.', '{"users":false,"quotes":false,"invoices":false,"payments":false,"delivery":false,"inventory":false,"production":false,"reports":true,"void":false}',3);
alter table public.access_profiles enable row level security;
create policy profiles_read on public.access_profiles for select to authenticated using (true);
grant select on public.access_profiles to authenticated;

alter table public.memberships add column profile_key text not null default 'sales' references public.access_profiles(profile_key);
alter table public.memberships add column email text not null default '';
alter table public.memberships add column display_name text not null default '';
alter table public.memberships add constraint role_profile_match check (
 (role='admin' and profile_key='admin') or
 (role='operator' and profile_key<>'admin')
);

create table public.pending_invites (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete restrict,
 email text not null check(length(email)<=254 and email=lower(trim(email)) and position('@' in email)>1),
 display_name text not null default '' check(length(display_name)<=100),
 role text not null check(role in ('admin','operator')),
 profile_key text not null references public.access_profiles(profile_key),
 status text not null default 'pending' check(status in ('pending','accepted','revoked')),
 invited_by uuid references auth.users(id),
 claimed_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 accepted_at timestamptz,
 updated_at timestamptz not null default now(),
 unique (business_id,email),
 check ((role='admin' and profile_key='admin') or (role='operator' and profile_key<>'admin'))
);
create index pending_invites_business on public.pending_invites(business_id,status);
alter table public.pending_invites enable row level security;
create policy pending_invites_admin_read on public.pending_invites for select to authenticated using(public.bobc_is_admin(business_id));
grant select on public.pending_invites to authenticated;

-- El administrador se provisiona de forma privada, fuera del repositorio público.
create function public.bobc_claim_invitation()
returns table(business_id uuid, profile_key text, role text, display_name text)
language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_email text; v_inv public.pending_invites%rowtype; v_verified timestamptz;
begin
 if v_user is null then raise exception 'Debes iniciar sesión'; end if;
 select lower(trim(u.email)), u.email_confirmed_at into v_email,v_verified
 from auth.users u where u.id=v_user;
 if v_email is null or v_verified is null then raise exception 'Verifica tu correo antes de activar BOBC'; end if;
 for v_inv in
  select * from public.pending_invites i where i.email=v_email and i.status='pending'
  order by created_at for update
 loop
  insert into public.memberships (business_id,user_id,role,profile_key,active,email,display_name)
  values (v_inv.business_id,v_user,v_inv.role,v_inv.profile_key,true,v_email,v_inv.display_name)
  on conflict (business_id,user_id) do nothing;
  update public.pending_invites i set status='accepted',claimed_by=v_user,accepted_at=now(),updated_at=now()
  where i.id=v_inv.id;
  insert into public.audit_log(business_id,actor_user_id,action,entity_type,entity_id,after_json)
  values (v_inv.business_id,v_user,'activate_user','membership',v_user,
     pg_catalog.jsonb_build_object('email',v_email,'profile',v_inv.profile_key));
 end loop;
 return query select m.business_id,m.profile_key,m.role,m.display_name
 from public.memberships m where m.user_id=v_user and m.active;
end $$;

create function public.bobc_invite_user(p_business_id uuid, p_email text, p_profile_key text, p_name text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_mail text := lower(trim(coalesce(p_email,''))); v_id uuid; v_exists boolean;
begin
 if auth.uid() is null or not public.bobc_is_admin(p_business_id) then raise exception 'Solo un administrador puede crear usuarios'; end if;
 if length(v_mail)>254 or v_mail !~ '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$' then raise exception 'Correo no válido'; end if;
 if p_profile_key not in ('sales','production','viewer') then raise exception 'El perfil administrador no se asigna mediante invitaciones'; end if;
 if length(trim(coalesce(p_name,'')))>100 then raise exception 'Nombre demasiado largo'; end if;
 select exists(select 1 from public.memberships m where m.business_id=p_business_id and m.email=v_mail) into v_exists;
 if v_exists then raise exception 'Este usuario ya pertenece al negocio; usa Editar usuario'; end if;
 insert into public.pending_invites(business_id,email,display_name,role,profile_key,status,invited_by)
 values(p_business_id,v_mail,trim(coalesce(p_name,'')),'operator',p_profile_key,'pending',auth.uid())
 on conflict (business_id,email) do update
 set display_name=excluded.display_name,profile_key=excluded.profile_key,status='pending',invited_by=auth.uid(),updated_at=now(),claimed_by=null,accepted_at=null
 where public.pending_invites.status<>'accepted'
 returning id into v_id;
 if v_id is null then raise exception 'La invitación ya fue utilizada'; end if;
 insert into public.audit_log(business_id,actor_user_id,action,entity_type,entity_id,after_json)
 values(p_business_id,auth.uid(),'invite_user','invitation',v_id,
    pg_catalog.jsonb_build_object('email',v_mail,'profile',p_profile_key));
 return v_id;
end $$;

create function public.bobc_update_user(p_business_id uuid,p_user_id uuid,p_profile_key text,p_active boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_before public.memberships%rowtype;
begin
 if auth.uid() is null or not public.bobc_is_admin(p_business_id) then raise exception 'Solo el administrador puede cambiar perfiles'; end if;
 if p_user_id=auth.uid() then raise exception 'No puedes modificar tu propio acceso'; end if;
 if p_profile_key not in ('sales','production','viewer') then raise exception 'No puedes asignar administrador desde esta pantalla'; end if;
 select * into v_before from public.memberships
 where business_id=p_business_id and user_id=p_user_id for update;
 if not found then raise exception 'Usuario no encontrado'; end if;
 if v_before.role='admin' then raise exception 'El administrador principal no se puede alterar'; end if;
 update public.memberships set profile_key=p_profile_key,active=p_active,updated_at=now()
 where business_id=p_business_id and user_id=p_user_id;
 insert into public.audit_log(business_id,actor_user_id,action,entity_type,entity_id,before_json,after_json)
 values(p_business_id,auth.uid(),'update_user','membership',p_user_id,
  pg_catalog.jsonb_build_object('profile',v_before.profile_key,'active',v_before.active),
  pg_catalog.jsonb_build_object('profile',p_profile_key,'active',p_active));
 return true;
end $$;

create function public.bobc_revoke_invitation(p_business_id uuid,p_invitation_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.bobc_is_admin(p_business_id) then raise exception 'Solo el administrador puede cancelar invitaciones'; end if;
 update public.pending_invites set status='revoked',updated_at=now()
 where business_id=p_business_id and id=p_invitation_id and status='pending';
 if not found then raise exception 'Invitación ya aceptada o inexistente'; end if;
 insert into public.audit_log(business_id,actor_user_id,action,entity_type,entity_id)
 values(p_business_id,auth.uid(),'revoke_invitation','invitation',p_invitation_id);
 return true;
end $$;

-- Las funciones RPC de gestión son privilegiadas, validan auth.uid() y rol en DB.
revoke all on function public.bobc_claim_invitation() from public,anon;
revoke all on function public.bobc_invite_user(uuid,text,text,text) from public,anon;
revoke all on function public.bobc_update_user(uuid,uuid,text,boolean) from public,anon;
revoke all on function public.bobc_revoke_invitation(uuid,uuid) from public,anon;
grant execute on function public.bobc_claim_invitation() to authenticated;
grant execute on function public.bobc_invite_user(uuid,text,text,text) to authenticated;
grant execute on function public.bobc_update_user(uuid,uuid,text,boolean) to authenticated;
grant execute on function public.bobc_revoke_invitation(uuid,uuid) to authenticated;