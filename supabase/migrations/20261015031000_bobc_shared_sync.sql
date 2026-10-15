-- BOBC 0.8 — almacenamiento compartido transaccional con snapshots, roles e historial.
-- Protección: RLS cerrado; toda escritura mediante RPC autenticada e idempotente.
-- Este almacén es una etapa de compatibilidad para datos legacy schema:1; las tablas normalizadas
-- seguirán siendo la meta de evolución, pero NUNCA deben recibir escrituras parciales clientes.
create table if not exists public.bobc_shared_state (
 business_id uuid primary key references public.businesses(id) on delete restrict,
 revision bigint not null default 0 check (revision>=0),
 state jsonb not null check (jsonb_typeof(state)='object'),
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
create table if not exists public.bobc_sync_events (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete restrict,
 operation_id uuid not null,
 revision bigint not null,
 actor_id uuid not null references auth.users(id) on delete restrict,
 affected jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(business_id,operation_id),unique(business_id,revision)
);
create index if not exists bobc_sync_events_order on public.bobc_sync_events(business_id,revision desc);
alter table public.bobc_shared_state enable row level security;
alter table public.bobc_sync_events enable row level security;
revoke all on public.bobc_shared_state,public.bobc_sync_events from public,anon,authenticated;
grant select on public.bobc_shared_state to authenticated;
grant select on public.bobc_sync_events to authenticated;
create policy bobc_shared_member_read on public.bobc_shared_state for select to authenticated
 using(public.bobc_is_member(business_id));
create policy bobc_events_admin_read on public.bobc_sync_events for select to authenticated
 using(public.bobc_is_admin(business_id));

-- append only / integrity checks on snapshots; fail closed if unexpected mutation.
create or replace function public.bobc_array_unique(p_array jsonb)
returns boolean language sql immutable set search_path='' as $$
 select coalesce((select count(*)=count(distinct item->>'id') and bool_and(item ? 'id' and jsonb_typeof(item->'id')='string' and length(item->>'id')>0) from jsonb_array_elements(p_array) as item),true)
$$;
revoke all on function public.bobc_array_unique(jsonb) from public,anon;

create or replace function public.bobc_sync_pull(p_business_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare row record;
begin
 if auth.uid() is null or not public.bobc_is_member(p_business_id) then raise exception 'Acceso al negocio denegado'; end if;
 select s.revision,s.state,s.updated_at into row from public.bobc_shared_state s where s.business_id=p_business_id;
 if not found then return jsonb_build_object('revision',0,'state',null);end if;
 return jsonb_build_object('revision',row.revision,'state',row.state,'updated_at',row.updated_at);
end $$;

create or replace function public.bobc_sync_commit(p_business_id uuid,p_revision bigint,p_state jsonb,p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_uid uuid:=auth.uid();v_profile text;v_old jsonb;v_old_array jsonb;v_new_array jsonb;
 v_rev bigint;v_key text;v_item jsonb;v_prior jsonb;v_child jsonb;v_paid bigint;v_invoice jsonb;
 v_old_invoice jsonb;v_new_invoice jsonb;v_old_quote jsonb;v_new_quote jsonb;
 v_is_admin boolean;v_can_invoice boolean;v_can_prod boolean;v_can_quote boolean;
 v_changed jsonb:='{}'::jsonb;v_r jsonb;v_total bigint;
 v_array_keys text[]:=array['products','recipes','skus','quotes','invoices','payments','documents','calculations','inventory','movements','supplies','supplyMovements','packagingLinks','expenses','drafts','auditLog'];
begin
 if v_uid is null or p_business_id is null or p_operation_id is null then raise exception 'Autenticación u operación no válida';end if;
 select m.profile_key into v_profile from public.memberships m where m.business_id=p_business_id and m.user_id=v_uid and m.active;
 if v_profile is null then raise exception 'Perfil no autorizado';end if;
 v_is_admin:=(v_profile='admin');v_can_invoice:=(v_profile in ('admin','sales'));v_can_prod:=(v_profile in ('admin','sales','production'));v_can_quote:=v_is_admin;
 if p_revision is null or p_revision<0 or p_state is null or jsonb_typeof(p_state)<>'object' then raise exception 'Datos de sincronización inválidos';end if;
 if pg_column_size(p_state)>6000000 then raise exception 'Datos exceden límite de seguridad de 6 MB';end if;
 if (p_state->>'schema') is distinct from '1' or jsonb_typeof(p_state->'settings')<>'object' then raise exception 'Esquema BOBC incompatible';end if;
 for v_key in select unnest(v_array_keys) loop
  if jsonb_typeof(p_state->v_key)<>'array' then raise exception 'Lista inválida en %',v_key;end if;
  if v_key=any(array['products','recipes','skus','quotes','invoices','payments','documents','movements','supplies','supplyMovements','expenses','drafts','auditLog'])
     and not public.bobc_array_unique(p_state->v_key) then raise exception 'Identificadores duplicados o incompletos en %',v_key;end if;
 end loop;
 -- Serializar todas las peticiones del mismo negocio; evita carrera en primera inicialización.
 perform 1 from public.businesses b where b.id=p_business_id for update;
 if not found then raise exception 'Negocio desconocido';end if;
 select e.revision into v_rev from public.bobc_sync_events e where e.business_id=p_business_id and e.operation_id=p_operation_id;
 if found then return jsonb_build_object('revision',v_rev,'duplicate',true);end if;
 select s.revision,s.state into v_rev,v_old from public.bobc_shared_state s where s.business_id=p_business_id for update;
 if not found then v_rev:=0;v_old:=null;end if;
 if v_rev<>p_revision then raise exception 'CONFLICTO_REVISION: datos actualizados en otro teléfono. Recarga antes de guardar';end if;
 if v_old is null then
  if not v_is_admin then raise exception 'Solo el administrador puede activar la base compartida';end if;
  if p_revision<>0 then raise exception 'Revisión inicial incorrecta';end if;
 else
  if (p_state->>'created') is distinct from (v_old->>'created') and not (v_is_admin and coalesce(jsonb_array_length(v_old->'invoices'),0)=0 and coalesce(jsonb_array_length(v_old->'quotes'),0)=0 and coalesce(jsonb_array_length(v_old->'payments'),0)=0 and coalesce(jsonb_array_length(v_old->'products'),0)=0) then raise exception 'No se permite reemplazar identidad de la base';end if;
  if p_state->'settings' is distinct from v_old->'settings' and not v_is_admin then raise exception 'Configuración reservada al administrador';end if;
  -- Protección contra eliminación accidental de registros y cambios fuera del rol.
  for v_key in select unnest(v_array_keys) loop
    v_old_array:=coalesce(v_old->v_key,'[]'::jsonb);v_new_array:=p_state->v_key;
    if v_old_array is distinct from v_new_array then
      if v_key in ('products','recipes','skus','inventory','movements','supplies','supplyMovements','packagingLinks','calculations') and not v_can_prod then raise exception 'Producción e inventario no autorizados';end if;
      if v_key in ('invoices','payments') and not v_can_invoice then raise exception 'Facturación no autorizada';end if;
      if v_key='documents' and not (v_can_invoice or v_can_prod) then raise exception 'Documentación no autorizada';end if;
      if v_key='quotes' and not v_can_invoice then raise exception 'Cotizaciones no autorizadas';end if;
      if v_key='expenses' and not v_is_admin then raise exception 'Gastos reservados al administrador';end if;
      if v_key='drafts' then
        if not v_is_admin and exists(select 1 from jsonb_array_elements(v_old_array) d where d->>'kind'='quote' and not exists(select 1 from jsonb_array_elements(v_new_array) n where n->>'id'=d->>'id' and n=d)) then raise exception 'El operador no puede eliminar cotizaciones en borrador';end if;
        -- validar cada documento existente/nuevo por su tipo (facturas vs cotizaciones)
        for v_item in select value from jsonb_array_elements(v_new_array) loop
          if v_item->>'kind'='quote' and not v_can_quote and not exists(select 1 from jsonb_array_elements(v_old_array) prior where prior->>'id'=v_item->>'id' and prior=v_item) then raise exception 'El operador no puede crear ni modificar cotizaciones';end if;
        end loop;
      end if;
      if v_key in ('payments','documents','movements','supplyMovements','calculations','expenses','recipes','auditLog') then
       if exists(select 1 from jsonb_array_elements(v_old_array) old_item where not exists
          (select 1 from jsonb_array_elements(v_new_array) new_item where new_item->>'id'=old_item->>'id' and new_item=old_item)) then
         raise exception 'No se pueden eliminar ni alterar registros históricos: %',v_key;
       end if;
      end if;
      if v_key in ('products','skus','supplies','inventory') then
       if exists(select 1 from jsonb_array_elements(v_old_array) old_item where not exists
          (select 1 from jsonb_array_elements(v_new_array) new_item where new_item->>'id'=old_item->>'id')) then
         raise exception 'No se pueden eliminar registros base: %',v_key;
       end if;
      end if;
      v_changed:=v_changed||jsonb_build_object(v_key,jsonb_array_length(v_new_array)-jsonb_array_length(v_old_array));
    end if;
  end loop;
  -- Cotizaciones: solo cambios en saleId o anulación por administrador; sin alterar líneas, precios ni números.
  for v_old_quote in select value from jsonb_array_elements(v_old->'quotes') loop
    select value into v_new_quote from jsonb_array_elements(p_state->'quotes') value where value->>'id'=v_old_quote->>'id';
    if not found then raise exception 'No se elimina una cotización emitida';end if;
    if v_old_quote<>v_new_quote then
      if (v_old_quote- 'saleId')=(v_new_quote-'saleId') then
        if coalesce(v_old_quote->>'saleId','')<>'' then raise exception 'La cotización ya fue convertida';end if;
        if not exists(select 1 from jsonb_array_elements(p_state->'invoices') i where i->>'id'=v_new_quote->>'saleId' and i->>'sourceQuoteId'=v_new_quote->>'id') then raise exception 'Vínculo cotización/factura inválido';end if;
      elsif v_is_admin and (v_old_quote-'cancelled'-'status'-'voidReason'-'voidedAt'-'voidedBy')=(v_new_quote-'cancelled'-'status'-'voidReason'-'voidedAt'-'voidedBy')
        and coalesce((v_old_quote->>'cancelled')::boolean,false)=false and coalesce((v_new_quote->>'cancelled')::boolean,false)=true
        and nullif(trim(v_new_quote->>'voidReason'),'') is not null
        and not exists(select 1 from jsonb_array_elements(p_state->'invoices') i where i->>'sourceQuoteId'=v_new_quote->>'id') then null;
      else raise exception 'No se permite modificar una cotización emitida';end if;
    end if;
  end loop;
  if not v_can_quote and exists(select 1 from jsonb_array_elements(p_state->'quotes') n where not exists
     (select 1 from jsonb_array_elements(v_old->'quotes') o where o->>'id'=n->>'id')) then raise exception 'No puedes crear cotizaciones';end if;
  -- Facturas emitidas: solo transición a entregada o anulación autorizada; nunca cambiar líneas o precios.
  for v_old_invoice in select value from jsonb_array_elements(v_old->'invoices') loop
    select value into v_new_invoice from jsonb_array_elements(p_state->'invoices') value where value->>'id'=v_old_invoice->>'id';
    if not found then raise exception 'No se puede eliminar una factura emitida';end if;
    if v_old_invoice<>v_new_invoice then
      if (v_old_invoice-'delivered'-'deliveredAt')=(v_new_invoice-'delivered'-'deliveredAt')
         and coalesce((v_old_invoice->>'delivered')::boolean,false)=false and coalesce((v_new_invoice->>'delivered')::boolean,false)=true
         and v_can_invoice then null;
      elsif v_is_admin and (v_old_invoice-'cancelled'-'status'-'voidReason'-'voidedAt'-'voidedBy')=(v_new_invoice-'cancelled'-'status'-'voidReason'-'voidedAt'-'voidedBy')
         and coalesce((v_new_invoice->>'cancelled')::boolean,false)=true and coalesce((v_old_invoice->>'cancelled')::boolean,false)=false
         and nullif(trim(v_new_invoice->>'voidReason'),'') is not null and coalesce((v_old_invoice->>'delivered')::boolean,false)=false
         and not exists(select 1 from jsonb_array_elements(v_old->'payments') p where p->>'invoiceId'=v_old_invoice->>'id' and coalesce((p->>'voided')::boolean,false)=false) then null;
      else raise exception 'Factura emitida inmutable: no se permiten cambios de productos/precios/estado';end if;
    end if;
  end loop;
  -- Validación de pagos nuevos, saldo total y referencias.
  for v_item in select value from jsonb_array_elements(p_state->'payments') loop
    if not exists(select 1 from jsonb_array_elements(v_old->'payments') p where p->>'id'=v_item->>'id') then
      if not v_can_invoice then raise exception 'Cobros no autorizados';end if;
      select value into v_invoice from jsonb_array_elements(p_state->'invoices') value where value->>'id'=v_item->>'invoiceId';
      if not found or coalesce((v_invoice->>'cancelled')::boolean,false) then raise exception 'Pago sobre factura no vigente';end if;
      if coalesce(v_item->>'amountCents','') !~ '^[0-9]{1,14}$' or (v_item->>'amountCents')::bigint<=0 then raise exception 'Monto de pago incorrecto';end if;
    end if;
  end loop;
 end if;
 -- Invariantes finales aplican también a datos importados.
 for v_invoice in select value from jsonb_array_elements(p_state->'invoices') loop
  if coalesce(v_invoice->>'totalCents','') !~ '^[0-9]{1,14}$' or (v_invoice->>'totalCents')::bigint<=0 then raise exception 'Total de factura inválido';end if;
  if jsonb_typeof(v_invoice->'lines')<>'array' then raise exception 'Factura sin detalle';end if;
  select coalesce(sum((p->>'amountCents')::bigint),0) into v_paid from jsonb_array_elements(p_state->'payments') p
   where p->>'invoiceId'=v_invoice->>'id' and coalesce((p->>'voided')::boolean,false)=false;
  if v_paid>(v_invoice->>'totalCents')::bigint then raise exception 'Total abonado excede el importe de factura';end if;
  if coalesce((v_invoice->>'cancelled')::boolean,false) and v_paid>0 then raise exception 'Factura anulada tiene pagos activos';end if;
  if nullif(v_invoice->>'sourceQuoteId','') is not null then
   if not exists(select 1 from jsonb_array_elements(p_state->'quotes') q where q->>'id'=v_invoice->>'sourceQuoteId' and not coalesce((q->>'cancelled')::boolean,false)) then raise exception 'Cotización original inválida';end if;
  end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p_state->'payments') p where not exists
  (select 1 from jsonb_array_elements(p_state->'invoices') i where i->>'id'=p->>'invoiceId')) then raise exception 'Pago sin factura';end if;
 if exists(select 1 from jsonb_array_elements(p_state->'invoices') a join jsonb_array_elements(p_state->'invoices') b on a->>'sourceQuoteId'=b->>'sourceQuoteId'
  and a->>'id'<>b->>'id' where nullif(a->>'sourceQuoteId','') is not null and not coalesce((a->>'cancelled')::boolean,false) and not coalesce((b->>'cancelled')::boolean,false)) then
  raise exception 'Cotización facturada más de una vez';end if;
 if exists(select 1 from jsonb_array_elements(p_state->'invoices') a join jsonb_array_elements(p_state->'invoices') b on a->>'number'=b->>'number' and a->>'id'<>b->>'id') then raise exception 'Número de factura duplicado';end if;
 if exists(select 1 from jsonb_array_elements(p_state->'payments') a join jsonb_array_elements(p_state->'payments') b on a->>'number'=b->>'number' and a->>'id'<>b->>'id') then raise exception 'Número de recibo duplicado';end if;
 -- Liquidación de stocks; negativos no admitidos, salvo incidencias históricas importadas previamente (rechazar import).
 if exists(select 1 from (
  select m->>'skuId' sku,sum(case when m->>'type'='entrada' then (m->>'qty')::int else -(m->>'qty')::int end) qty
  from jsonb_array_elements(p_state->'movements') m group by m->>'skuId'
 ) t where t.qty<0) then raise exception 'Inventario terminado negativo';end if;
 if exists(select 1 from (
  select m->>'supplyId' sid,sum(case when m->>'type'='entrada' then (m->>'qty')::int else -(m->>'qty')::int end) qty
  from jsonb_array_elements(p_state->'supplyMovements') m group by m->>'supplyId'
 ) t where t.qty<0) then raise exception 'Inventario de materiales negativo';end if;
 -- auditoría append-only siempre a nivel servidor.
 if v_old is null then
  insert into public.bobc_shared_state(business_id,revision,state,updated_by)
  values(p_business_id,1,p_state,v_uid);
 else
  update public.bobc_shared_state set revision=v_rev+1,state=p_state,updated_at=now(),updated_by=v_uid where business_id=p_business_id;
 end if;
 insert into public.bobc_sync_events(business_id,operation_id,revision,actor_id,affected)
 values(p_business_id,p_operation_id,v_rev+1,v_uid,v_changed);
 return jsonb_build_object('revision',v_rev+1,'duplicate',false);
end $$;
revoke all on function public.bobc_sync_pull(uuid) from public,anon;
revoke all on function public.bobc_sync_commit(uuid,bigint,jsonb,uuid) from public,anon;
grant execute on function public.bobc_sync_pull(uuid),public.bobc_sync_commit(uuid,bigint,jsonb,uuid) to authenticated;