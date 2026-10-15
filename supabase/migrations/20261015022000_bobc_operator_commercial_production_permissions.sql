-- BOBC 0.8 — perfiles operador y permisos de escritura, aplicada en BOBC-PRIVATE.
-- Replica idempotente de la migración bobc_operator_commercial_production_permissions.
-- Nunca permitir ediciones cliente de facturas emitidas, pagos o entregas; se requieren RPCs.

update public.access_profiles
set display_name='Operador comercial y producción',
 description='Puede facturar desde borradores y cotizaciones, registrar abonos y entregas, modificar recetas e inventario. No puede anular ni modificar documentos emitidos.',
 permissions='{"users":false,"quotes":false,"quote_convert":true,"invoices":true,"payments":true,"delivery":true,"inventory":true,"production":true,"reports":true,"void":false,"issued_document_edit":false}'::jsonb
where profile_key='sales';

create or replace function public.bobc_can_edit_production(p_business_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (select 1 from public.memberships m
 where m.business_id=p_business_id and m.user_id=(select auth.uid())
 and m.active=true and m.profile_key in ('admin','sales','production'));
$$;
revoke all on function public.bobc_can_edit_production(uuid) from public,anon;
grant execute on function public.bobc_can_edit_production(uuid) to authenticated;

create or replace function public.bobc_can_invoice(p_business_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists (select 1 from public.memberships m
 where m.business_id=p_business_id and m.user_id=(select auth.uid())
 and m.active=true and m.profile_key in ('admin','sales'));
$$;
revoke all on function public.bobc_can_invoice(uuid) from public,anon;
grant execute on function public.bobc_can_invoice(uuid) to authenticated;

drop policy if exists quote_draft_insert on public.quote_drafts;
drop policy if exists quote_draft_update on public.quote_drafts;
create policy quote_draft_insert on public.quote_drafts
for insert to authenticated with check
(public.bobc_is_admin(business_id) and created_by=(select auth.uid()) and status='draft' and version=1);
create policy quote_draft_update on public.quote_drafts
for update to authenticated using (public.bobc_is_admin(business_id) and status='draft')
with check (public.bobc_is_admin(business_id) and status='draft');

drop policy if exists invoice_draft_insert on public.invoice_drafts;
drop policy if exists invoice_draft_update on public.invoice_drafts;
create policy invoice_draft_insert on public.invoice_drafts
for insert to authenticated with check
(public.bobc_can_invoice(business_id) and created_by=(select auth.uid()) and status='draft' and version=1);
create policy invoice_draft_update on public.invoice_drafts
for update to authenticated using
(public.bobc_can_invoice(business_id) and status='draft' and
(created_by=(select auth.uid()) or public.bobc_is_admin(business_id)))
with check
(public.bobc_can_invoice(business_id) and status='draft' and
(created_by=(select auth.uid()) or public.bobc_is_admin(business_id)));

do $$ declare t text;begin
foreach t in array array['products','recipes','skus','supplies'] loop
 execute format('drop policy if exists production_insert on public.%I',t);
 execute format('drop policy if exists production_update on public.%I',t);
 execute format('create policy production_insert on public.%I for insert to authenticated with check (public.bobc_can_edit_production(business_id))',t);
 execute format('create policy production_update on public.%I for update to authenticated using (public.bobc_can_edit_production(business_id)) with check (public.bobc_can_edit_production(business_id))',t);
end loop;
end $$;
