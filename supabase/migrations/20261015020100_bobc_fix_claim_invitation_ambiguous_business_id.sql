-- BOBC 0.8: Evitar colisión del OUT parameter business_id con índice PK.
-- Prueba con transacción ROLLBACK verificó perfil admin sin mutar tablas.
create or replace function public.bobc_claim_invitation()
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
  on conflict on constraint memberships_pkey do nothing;
  update public.pending_invites i set status='accepted',claimed_by=v_user,accepted_at=now(),updated_at=now()
  where i.id=v_inv.id;
  insert into public.audit_log(business_id,actor_user_id,action,entity_type,entity_id,after_json)
  values (v_inv.business_id,v_user,'activate_user','membership',v_user,
     pg_catalog.jsonb_build_object('email',v_email,'profile',v_inv.profile_key));
 end loop;
 return query select m.business_id,m.profile_key,m.role,m.display_name
 from public.memberships m where m.user_id=v_user and m.active;
end $$;
