-- BOBC 0.8 · Fundación multiusuario privada
-- Proyecto: BOBC-PRIVATE (tsjbizuoxorebvccwmig)
-- No contiene datos de negocio ni usuarios. No borra ninguna tabla existente.
-- Todas las tablas públicas tienen RLS, sin acceso anónimo.

create extension if not exists pgcrypto with schema extensions;

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check(length(trim(display_name)) between 1 and 160),
  currency text not null default 'DOP' check(currency = 'DOP'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  business_id uuid not null references public.businesses(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check(role in ('admin','operator')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (business_id,user_id)
);
create index memberships_user_idx on public.memberships(user_id,business_id) where active;

-- Helpers ejecutados como propietario DB, sin leer JWT de terceros.
-- La pertenencia no se puede autoasignar con el cliente público.
create function public.bobc_is_member(p_business_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.business_id=p_business_id and m.user_id=(select auth.uid()) and m.active
  );
$$;
create function public.bobc_is_admin(p_business_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.business_id=p_business_id and m.user_id=(select auth.uid()) and m.active and m.role='admin'
  );
$$;
revoke all on function public.bobc_is_member(uuid) from public,anon;
revoke all on function public.bobc_is_admin(uuid) from public,anon;
grant execute on function public.bobc_is_member(uuid), public.bobc_is_admin(uuid) to authenticated;

create table public.products (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete restrict,
 name text not null check(length(trim(name)) between 1 and 220),
 variant text not null default '', active boolean not null default true,
 legacy_id text, created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,id), unique(business_id,legacy_id)
);
create index products_business_idx on public.products(business_id,name);

create table public.recipes (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 product_id uuid not null references public.products(id) on delete restrict,
 version integer not null check(version>=1),title text not null default '',
 yield_ml numeric(16,3) not null check(yield_ml>0), extra_ml numeric(16,3) not null default 0 check(extra_ml>=0),
 ingredients_json jsonb not null default '[]'::jsonb check(jsonb_typeof(ingredients_json)='array'),
 extra_json jsonb not null default '{}'::jsonb check(jsonb_typeof(extra_json)='object'),
 legacy_id text,created_at timestamptz not null default now(),
 unique(business_id,id),unique(business_id,product_id,version),unique(business_id,legacy_id),
 foreign key(business_id,product_id) references public.products(business_id,id)
);
create index recipes_product_idx on public.recipes(business_id,product_id);

create table public.skus (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 product_id uuid not null references public.products(id) on delete restrict,
 size_ml integer not null check(size_ml>0),tier text not null default '',
 price_cents bigint not null default 0 check(price_cents>=0),
 bottle_cost_cents bigint not null default 0 check(bottle_cost_cents>=0),
 label_cost_cents bigint not null default 0 check(label_cost_cents>=0),
 active boolean not null default true, legacy_id text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,id),unique(business_id,legacy_id),
 foreign key(business_id,product_id) references public.products(business_id,id)
);
create index skus_business_product_idx on public.skus(business_id,product_id);

create table public.quote_drafts (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid references auth.users(id) on delete restrict,
 version integer not null default 1 check(version>=1),
 status text not null default 'draft' check(status in ('draft','issued','discarded')),
 payload_json jsonb not null default '{}'::jsonb check(jsonb_typeof(payload_json)='object'),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,id)
);
create index quote_drafts_business_idx on public.quote_drafts(business_id,updated_at desc);

create table public.quotes (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 number text not null, status text not null default 'issued' check(status in ('issued','cancelled')),
 total_cents bigint not null check(total_cents>0),
 lines_json jsonb not null check(jsonb_typeof(lines_json)='array'),
 snapshot_json jsonb not null check(jsonb_typeof(snapshot_json)='object'),
 source_draft_id uuid references public.quote_drafts(id) on delete restrict,
 issued_by uuid not null references auth.users(id) on delete restrict,
 issued_at timestamptz not null default now(),
 cancelled_at timestamptz,cancelled_by uuid references auth.users(id),cancel_reason text,
 legacy_id text,unique(business_id,id),unique(business_id,number),
 unique(business_id,source_draft_id),unique(business_id,legacy_id),
 foreign key(business_id,source_draft_id) references public.quote_drafts(business_id,id),
 check((status='issued' and cancelled_at is null and cancelled_by is null) or
       (status='cancelled' and cancelled_at is not null and cancelled_by is not null and length(trim(cancel_reason))>=3))
);
create index quotes_business_status_idx on public.quotes(business_id,status,issued_at desc);

create table public.invoice_drafts (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 source_quote_id uuid references public.quotes(id) on delete restrict,
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid references auth.users(id) on delete restrict,
 version integer not null default 1 check(version>=1),
 status text not null default 'draft' check(status in ('draft','issued','discarded')),
 payload_json jsonb not null default '{}'::jsonb check(jsonb_typeof(payload_json)='object'),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,id),
 foreign key(business_id,source_quote_id) references public.quotes(business_id,id)
);
create index invoice_drafts_business_idx on public.invoice_drafts(business_id,updated_at desc);

create table public.invoices (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete restrict,
 number text not null,status text not null default 'issued' check(status in ('issued','cancelled')),
 total_cents bigint not null check(total_cents>0),
 snapshot_json jsonb not null check(jsonb_typeof(snapshot_json)='object'),
 source_quote_id uuid references public.quotes(id) on delete restrict,
 source_draft_id uuid references public.invoice_drafts(id) on delete restrict,
 issued_at timestamptz not null default now(), issued_by uuid not null references auth.users(id) on delete restrict,
 cancelled_at timestamptz,cancelled_by uuid references auth.users(id),cancel_reason text,
 legacy_id text,
 unique(business_id,id),unique(business_id,number),unique(business_id,source_quote_id),
 unique(business_id,source_draft_id),unique(business_id,legacy_id),
 foreign key(business_id,source_quote_id) references public.quotes(business_id,id),
 foreign key(business_id,source_draft_id) references public.invoice_drafts(business_id,id),
 check((status='issued' and cancelled_at is null and cancelled_by is null) or
       (status='cancelled' and cancelled_at is not null and cancelled_by is not null and length(trim(cancel_reason))>=3))
);
create index invoices_business_status_idx on public.invoices(business_id,status,issued_at desc);

create table public.invoice_lines (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 invoice_id uuid not null references public.invoices(id) on delete restrict,
 sku_id uuid references public.skus(id) on delete restrict,
 description_snapshot text not null check(length(trim(description_snapshot))>0),
 qty integer not null check(qty>0),unit_price_cents bigint not null check(unit_price_cents>=0),
 total_cents bigint not null check(total_cents>=0),
 foreign key(business_id,invoice_id) references public.invoices(business_id,id),
 foreign key(business_id,sku_id) references public.skus(business_id,id),
 check(total_cents=qty*unit_price_cents)
);
create index invoice_lines_invoice_idx on public.invoice_lines(business_id,invoice_id);

create table public.payments (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 invoice_id uuid not null references public.invoices(id) on delete restrict,
 receipt_number text not null,amount_cents bigint not null check(amount_cents>0),
 method text not null default 'efectivo',
 payment_label text not null default 'standard' check(payment_label in ('initial','installment','final','standard')),
 paid_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,
 idempotency_key uuid not null,
 reversed_at timestamptz,reversed_by uuid references auth.users(id),reverse_reason text,
 unique(business_id,id),unique(business_id,receipt_number),unique(business_id,idempotency_key),
 foreign key(business_id,invoice_id) references public.invoices(business_id,id),
 check((reversed_at is null and reversed_by is null) or
       (reversed_at is not null and reversed_by is not null and length(trim(reverse_reason))>=3))
);
create index payments_invoice_idx on public.payments(business_id,invoice_id,paid_at);

create table public.deliveries (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 invoice_id uuid not null references public.invoices(id) on delete restrict,
 status text not null default 'delivered' check(status='delivered'),
 delivered_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,
 idempotency_key uuid not null,
 unique(business_id,id),unique(business_id,invoice_id),unique(business_id,idempotency_key),
 foreign key(business_id,invoice_id) references public.invoices(business_id,id)
);

create table public.stock_movements (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 sku_id uuid not null references public.skus(id) on delete restrict,
 kind text not null check(kind in ('production','adjustment','delivery','reversal','migration')),
 qty_delta bigint not null check(qty_delta<>0),
 source_type text not null,source_id uuid not null,
 created_by uuid references auth.users(id), created_at timestamptz not null default now(),
 unique(business_id,source_type,source_id,sku_id),
 foreign key(business_id,sku_id) references public.skus(business_id,id)
);
create index stock_movements_sku_idx on public.stock_movements(business_id,sku_id,created_at);

create table public.supplies (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 name text not null,kind text not null default 'other',size_ml integer not null default 0 check(size_ml>=0),
 legacy_id text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(business_id,id),unique(business_id,legacy_id)
);
create table public.supply_movements (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 supply_id uuid not null references public.supplies(id) on delete restrict,
 qty_delta bigint not null check(qty_delta<>0),kind text not null,
 source_type text not null,source_id uuid not null,
 created_at timestamptz not null default now(),created_by uuid references auth.users(id),
 unique(business_id,source_type,source_id,supply_id),
 foreign key(business_id,supply_id) references public.supplies(business_id,id)
);

create table public.expenses (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 expense_at timestamptz not null default now(), name text not null,category text not null default '',
 amount_cents bigint not null check(amount_cents>0),created_by uuid references auth.users(id),
 legacy_id text,unique(business_id,legacy_id)
);
create index expenses_business_idx on public.expenses(business_id,expense_at desc);

create table public.documents (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 kind text not null check(kind in ('cotizacion','factura','recibo','calculo','ajuste')),
 ref_id uuid not null,number text not null,snapshot_json jsonb not null check(jsonb_typeof(snapshot_json)='object'),
 created_at timestamptz not null default now(),created_by uuid references auth.users(id),
 unique(business_id,kind,ref_id)
);
create index documents_business_idx on public.documents(business_id,created_at desc);

create table public.audit_log (
 id bigint generated always as identity primary key,business_id uuid not null references public.businesses(id) on delete restrict,
 actor_user_id uuid references auth.users(id),action text not null,entity_type text not null,entity_id uuid not null,
 before_json jsonb,after_json jsonb,reason text,created_at timestamptz not null default now()
);
create index audit_log_business_idx on public.audit_log(business_id,created_at desc);

create table public.idempotency_operations (
 business_id uuid not null references public.businesses(id) on delete restrict,
 operation_key uuid not null,operation_type text not null,result_ref uuid not null,
 created_at timestamptz not null default now(),
 primary key(business_id,operation_key)
);

create table public.document_sequences (
 business_id uuid not null references public.businesses(id) on delete restrict,
 document_kind text not null check(document_kind in ('FAC','COT','REC')),
 last_number bigint not null default 0 check(last_number>=0),
 primary key(business_id,document_kind)
);

create table public.migration_batches (
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id) on delete restrict,
 source_device text not null,source_schema integer not null,
 file_checksum text not null,imported_by uuid references auth.users(id),
 created_at timestamptz not null default now(), status text not null default 'review' check(status in ('review','imported','rejected')),
 unique(business_id,source_device,file_checksum)
);
create table public.legacy_id_map (
 migration_batch_id uuid not null references public.migration_batches(id) on delete restrict,
 entity_type text not null,legacy_id text not null,server_id uuid not null,
 primary key(migration_batch_id,entity_type,legacy_id)
);

-- Por defecto NINGUNA tabla es pública. Se revocan grants heredados de public.
do $$ declare t text; begin
 foreach t in array array[
  'businesses','memberships','products','recipes','skus','quote_drafts','quotes',
  'invoice_drafts','invoices','invoice_lines','payments','deliveries','stock_movements',
  'supplies','supply_movements','expenses','documents','audit_log',
  'idempotency_operations','document_sequences','migration_batches','legacy_id_map'
 ] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on table public.%I from public, anon, authenticated',t);
 end loop;
end $$;

-- Acceso de lectura sólo para integrantes de ese negocio.
create policy business_read on public.businesses for select to authenticated using(public.bobc_is_member(id));
create policy membership_read on public.memberships for select to authenticated using(public.bobc_is_member(business_id));

do $$ declare t text; begin
 foreach t in array array[
 'products','recipes','skus','quote_drafts','quotes','invoice_drafts','invoices',
 'invoice_lines','payments','deliveries','stock_movements','supplies','supply_movements',
 'expenses','documents','audit_log','migration_batches'
 ] loop
  execute format('create policy member_read on public.%I for select to authenticated using(public.bobc_is_member(business_id))',t);
 end loop;
end $$;

-- Bitácora sensible y migraciones: visibles sólo al administrador.
drop policy member_read on public.audit_log;
create policy admin_read on public.audit_log for select to authenticated using(public.bobc_is_admin(business_id));
drop policy member_read on public.migration_batches;
create policy admin_read on public.migration_batches for select to authenticated using(public.bobc_is_admin(business_id));

-- Las cuentas no pueden autoconcederse membresías.
-- Hasta tener onboarding seguro, membresías se asignan por admin de Supabase con Auth UIDs.

-- Edición local de borradores (no documentos emitidos) permitida a miembros activos.
create policy quote_draft_insert on public.quote_drafts for insert to authenticated
 with check(public.bobc_is_member(business_id) and created_by=(select auth.uid()) and status='draft' and version=1);
create policy quote_draft_update on public.quote_drafts for update to authenticated
 using(public.bobc_is_member(business_id) and status='draft')
 with check(public.bobc_is_member(business_id) and status='draft');
create policy invoice_draft_insert on public.invoice_drafts for insert to authenticated
 with check(public.bobc_is_member(business_id) and created_by=(select auth.uid()) and status='draft' and version=1);
create policy invoice_draft_update on public.invoice_drafts for update to authenticated
 using(public.bobc_is_member(business_id) and status='draft')
 with check(public.bobc_is_member(business_id) and status='draft');

-- Catálogo, empaques y gastos: escritura restringida al administrador hasta aprobar permisos.
do $$ declare t text; begin
 foreach t in array array['products','recipes','skus','supplies','expenses'] loop
  execute format('create policy admin_insert on public.%I for insert to authenticated with check(public.bobc_is_admin(business_id))',t);
  execute format('create policy admin_update on public.%I for update to authenticated using(public.bobc_is_admin(business_id)) with check(public.bobc_is_admin(business_id))',t);
 end loop;
end $$;

-- No se permite DELETE por Data API en ninguna tabla; no se permite insertar pagos ni facturas directamente.
-- Escritura de documentos emitidos y asientos: exclusivamente RPCs transaccionales (próxima migración).

do $$ declare t text;begin
 foreach t in array array[
  'businesses','memberships','products','recipes','skus','quote_drafts','quotes',
  'invoice_drafts','invoices','invoice_lines','payments','deliveries','stock_movements',
  'supplies','supply_movements','expenses','documents','audit_log','migration_batches'
 ] loop
  execute format('grant select on public.%I to authenticated',t);
 end loop;
 foreach t in array array['products','recipes','skus','quote_drafts','invoice_drafts','supplies','expenses'] loop
  execute format('grant insert, update on public.%I to authenticated',t);
 end loop;
end $$;

-- Protege campos que controlan identidad, negocio y concurrencia de borradores.
create function public.bobc_protect_draft() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
 if new.business_id is distinct from old.business_id
 or new.created_by is distinct from old.created_by
 or new.id is distinct from old.id
 or new.created_at is distinct from old.created_at
 or new.status is distinct from old.status then
  raise exception 'No se permite cambiar la identidad ni el estado del borrador';
 end if;
 if new.version<>old.version then raise exception 'La versión del borrador es administrada por el servidor'; end if;
 new.version:=old.version+1;
 new.updated_by:=auth.uid();
 new.updated_at:=now();
 return new;
end; $$;
create trigger quote_draft_protect before update on public.quote_drafts
 for each row execute function public.bobc_protect_draft();
create trigger invoice_draft_protect before update on public.invoice_drafts
 for each row execute function public.bobc_protect_draft();
revoke all on function public.bobc_protect_draft() from public,anon,authenticated;

-- Los reportes de saldo serán derivados de payments, no almacenados como totales manuales.
comment on schema public is 'BOBC 0.8: tablas con RLS obligatorio; funciones privilegiadas se desarrollan en migración separada';