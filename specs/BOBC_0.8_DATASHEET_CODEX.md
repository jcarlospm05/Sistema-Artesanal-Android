# BOBC SOFTWARE — DATASHEET TÉCNICO PARA CODEX
## BOBC 0.8 · Edición Privada y Sincronizada

**Documento:** especificación funcional, técnica, de datos, migración y pruebas para desarrollo asistido con Codex.  
**Fecha de corte:** 14 de octubre de 2026.  
**Estado:** REQUISITOS REGISTRADOS / DISEÑO PROPUESTO. **BOBC 0.8 NO ESTÁ IMPLEMENTADA NI COMPILADA.**  
**Producto que se debe modificar:** **BOBC Taller Artesanal 0.7.1 Android** (ponches y negocio artesanal de bebidas), **NO** BOBC 1.0 Artesanal Universal.  
**Idioma de UI:** español. **Moneda:** DOP, mostrar `RD$`; almacenar dinero en **centavos enteros**.  
**Usuarios objetivo:** dos personas en dos teléfonos Android, mismo negocio, roles ADMINISTRADOR y OPERADOR.  
**Repositorio:** https://github.com/jcarlospm05/Sistema-Artesanal-Android  
**Código Android existente:** `android-bobc-07/`. **Rama estable:** `main` (NO alterarla sin pruebas).  
**Rama BOBC Universal — NO TOCAR:** `bobc-1.0-artesanal-universal`.  
**Documento vivo original de requerimientos:** https://docs.google.com/document/d/1-eJvW3btrUEVUmJqyKnvPpFAPNHo3__xbi4o4b40vyw/edit  
**Datasheet histórico PWA 0.7:** https://docs.google.com/document/d/1-cXZsxlMHdnb6UF2hMOpmuqHwHtnqe517IREt5bcUV4/edit

> **CONTRATO PARA CODEX:** leer antes de escribir código. Mantener todas las funciones que actualmente operan en BOBC 0.7.1 y desarrollar v0.8 por fases verificables. No asumir que las propuestas de arquitectura o de interfaz ya fueron aprobadas, construidas ni probadas. Ante decisiones de negocio no definidas, usar implementaciones conservadoras y solicitar aprobación en lugar de inventar políticas.

---

## 1. Resumen del objetivo

Convertir la APK BOBC 0.7.1, hoy **autónoma/local y de un solo dispositivo**, en **BOBC 0.8 — edición privada para dos usuarios sincronizados**. Cada usuario tendrá BOBC instalada en su Android y visualizará los **mismos productos, fórmulas, inventarios, cotizaciones, facturas, pagos, recibos, entregas y dashboard** del mismo negocio, con permisos adecuados.

Cambios comerciales solicitados:

1. Usuario ADMINISTRADOR y usuario OPERADOR con privilegios distintos.
2. Sincronización segura de datos entre ambos Android.
3. Anular **facturas**, sin borrar su historia.
4. Anular **cotizaciones**, sin borrar su historia.
5. **Borrador editable de cotización** al enviar un cálculo; emisión solo por confirmación explícita.
6. **Borrador editable de factura** al convertir una cotización; emisión solo por confirmación explícita.
7. Cambiar nombres de `Calculadora A` y `Calculadora B` por títulos técnicos.
8. Si una factura ya está saldada, no mostrar un botón activo `Cobrar`; mostrar estado `Cobrada`/`Pagada` desactivado.
9. Si una factura ya está entregada, no mostrar un botón activo `Entregar`; mostrar estado `Entregada` desactivado.
10. Resumen y filtros de facturas con **inicial, abonos, múltiples pagos y saldos**.
11. Reemplazar las tarjetas grandes de facturas por **listado compacto de una o dos líneas por registro**.
12. Seguridad de APK personal: autenticación/biometría, datos locales y respaldos cifrados, firma estable, permisos mínimos.

**Restricción contractual:** no agregar un módulo obligatorio de clientes. Las cotizaciones y facturas pueden emitirse sin cliente registrado; referencia/nombre libre opcional es aceptable. No confundir documento comercial privado con factura fiscal habilitada por la DGII.

---

## 2. Estado real del código v0.7.1 (inspeccionado)

### 2.1 Estructura técnica

- App Android nativa contenedora de contenido web empaquetado: `android-bobc-07/app/src/main/java/com/bobc/artesanal/MainActivity.java`.
- `WebViewAssetLoader` sirve el sitio empaquetado desde `https://appassets.androidplatform.net/assets/www/index.html`.
- Contenido: `android-bobc-07/app/src/main/assets/www/`.
- Archivos funcionales principales: `app.js` (estado, navegación, documentos, formularios, cobros), `ui_v06.js` (dashboard/listas), `cocina_a.js` (rendimiento), `costos_b.js` (costos), `catalog_features.js`, `menu_v07.js`, `style.css`, `index.html`.
- Manifest: `android-bobc-07/app/src/main/AndroidManifest.xml`.
- Gradle: `android-bobc-07/app/build.gradle`: `applicationId='com.bobc.artesanal'`, `minSdk=26`, `targetSdk=33`, `versionCode=71`, `versionName='0.7.1'`; Java 17.
- CI existente: `.github/workflows/build-bobc-apk.yml` produce una **APK debug**, firmada con una clave de pruebas. No garantiza firma estable entre compilaciones.
- Manifest actual: `android:allowBackup="true"` (necesita política explícita para la versión privada); el código nativo usa `addJavascriptInterface(new DeviceBridge(), "BOBCAndroid")` y ofrece `saveBase64`, `shareBase64`, `printPage`.
- Almacenamiento web local: IndexedDB, base `bobc-pwa-local-v1`, object store `documents`, registro clave `state` con `schema: 1` y clave alternativa `state-v07-restaurada` al encontrar en `state` la estructura `schema: 2` de Universal. **No sobreescribir ni degradar esos registros.**
- No hay backend, cuentas autenticadas, roles, sincronización compartida ni cifrado fuerte de la información IndexedDB verificados en 0.7.1.
- La nueva sincronización requerirá conexión a red y autorización de internet en Android (la APK 0.7.1 fue diseñada como autónoma).

### 2.2 Datos existentes, esquema lógico `schema:1`

La función actual `fresh()` crea estas colecciones en un **único documento JSON de estado**:

```json
{
  "schema": 1,
  "created": "ISO-8601",
  "settings": { "company_name": "Mi Taller Artesanal" },
  "products": [],
  "recipes": [],
  "skus": [],
  "quotes": [],
  "invoices": [],
  "payments": [],
  "documents": [],
  "calculations": [],
  "inventory": [],
  "movements": [],
  "supplies": [],
  "supplyMovements": [],
  "packagingLinks": [],
  "expenses": []
}
```

Estructuras *observadas*, sin afirmar que sean campos exhaustivos:

- `products`: `id`, `name`, `variant`, `created`.
- `recipes`: `id`, `productId`, `yieldMl`, `extraMl`, `extraCost`, `additiveLabel`, `version`, `ingredients[]` (`name`, `quantity`, `unit`, `cost`) y metadatos.
- `skus`: `id`, `productId`, `sizeMl`, costos de envase/etiqueta, precios y variantes.
- `quotes` y `invoices`: `id`, `number`, `date`, `mode`, `shippingCents`, `discountCents`, `notes`, `lines[]` (`skuId`, `qty`, `unitPriceCents`), `totalCents`, `delivered`; algunas cotizaciones guardan `saleId` o `cancelled`.
- `payments`: `id`, `number` de recibo, `invoiceId`, `date`, `amountCents`, `method`.
- `documents`: `id`, `kind`, `refId`, `date`, `number`, `snapshot` con versión imprimible histórica.
- `inventory`, `movements`, `supplies`, `supplyMovements`, `packagingLinks`: control de unidades terminadas y consumibles de empaque; estudiar el detalle existente antes de modificar.
- `expenses`: `id`, `date`, `name`, `category`, `amountCents`.

**Puntos del código a inspeccionar primero:** `makeTransaction`, `saveTransaction`, `makeDoc`, `formHandler` y `clickHandler` en `app.js`; `salesView` y `stats` en `ui_v06.js`; `sendToPOS` en `costos_b.js`; la restauración `restoreLegacySnapshot` y la inicialización del DB.

### 2.3 Reglas funcionales existentes que NO se deben romper

- A (cocina) calcula el número de tandas enteras, volumen requerido/preparado y sobrante, ingredientes y compra; la mera planificación no descuenta inventario.
- B (costos) calcula material, envases, stickers, presentación, otros gastos, márgenes y precios.
- Hay pagos parciales, recibos por pago, facturas por cobrar, estado de entrega, existencias terminadas y material de empaque.
- Una cotización convertida no debe generar facturas duplicadas.
- Los pagos recibidos se contabilizan como entradas de dinero; no tratar la emisión de factura como efectivo cobrado.
- El descuento del inventario de producto terminado ocurre en la entrega; materiales de empaque asociados a embotellado no deben descontarse una segunda vez al entregar.
- Documentos y comprobantes deben poder visualizarse, imprimirse y compartirse como PNG por WhatsApp.
- No se debe exigir cliente creado previamente.
- Conservar identidad visual: `#FFA69E` coral, `#FAF3DD` crema, `#B8F2E6` menta, `#AED9E0` celeste, `#5E6472` gris; iconos de línea fina; menú lateral, barra inferior y formularios móviles.

---

## 3. Requisitos de negocio (estado: solicitados, aún no implementados)

### RF-01 — Identidad, usuarios y permisos

Un negocio `BOBC Taller Artesanal`, exactamente dos usuarios inicialmente: ADMINISTRADOR (propietario) y OPERADOR (persona encargada de facturación/operación). Distinto inicio de sesión por persona, mismo conjunto compartido de datos. El administrador puede invitar/revocar acceso y administrar ajustes. **Los permisos específicos de anular, borrar o ajustar movimientos aún deben aprobarse.**

**Matriz inicial PROPUESTA, no aprobada:**

| Acción | Administrador | Operador |
|---|:---:|:---:|
| Ver productos, cotizaciones, facturas y saldos | Sí | Sí |
| Crear/editar borradores de cotización y factura | Sí | Sí |
| Emitir cotización / emitir factura | Sí | Sí |
| Registrar abonos y emitir recibos | Sí | Sí |
| Registrar entregas | Sí | Sí |
| Anular documento emitido | Sí | **Pendiente de autorización** |
| Revertir cobros / devoluciones | Sí | **Pendiente** |
| Cambiar usuarios, seguridad, configuración global | Sí | No |
| Exportar respaldo completo | Sí | **Pendiente** |

**Obligatorio:** los permisos deben validarse en el backend mediante autenticación + RLS/funciones transaccionales, nunca solo ocultando botones en la interfaz.

### RF-02 — Cotizaciones en borrador, editables antes de emitir

`Costeo y Rentabilidad` → `Preparar cotización` → abrir formulario **BORRADOR** (sin número definitivo), permitir editar producto, cantidad, precio, transporte, descuento, notas, condiciones y datos de contacto opcionales → `Revisar` → botón inequívoco **Emitir cotización** → estado EMITIDA, número único y documento histórico.

El borrador puede guardarse, editarse y descartarse. Evitar generación inmediata de cotización al pulsar desde cálculo de costos. Una cotización emitida no se modifica silenciosamente; usar versión/nueva cotización o flujo de ajuste autorizado. El documento emitido tendrá snapshot inmutable.

### RF-03 — Facturación en borrador editable desde cotización

`Cotización emitida` → `Preparar factura` → generar **BORRADOR DE FACTURA** con copia de líneas/valores/observaciones (manteniendo `source_quote_id`) → permitir editar antes de confirmar → `Revisar` → **Emitir factura** → estado EMITIDA, número definitivo y documento de snapshot inmutable.

No alterar la cotización de origen cuando se edita el borrador de factura. Proteger contra doble pulsación o reconexión para no crear dos facturas. Definir explícitamente el caso de cotizaciones que pueden generar más de una factura; por defecto, **máximo una factura por cotización**, pendiente de futuras necesidades.

### RF-04 — Anulación de cotizaciones

Acción separada `Anular` con confirmación y motivo obligatorio; conservar documento, número, snapshots y autor/fecha/hora. Una cotización anulada no se puede convertir a factura. Si ya tiene factura asociada, **bloquear la anulación** y solicitar regla aprobada de ajuste (no modificar factura mediante efectos indirectos). El estado ANULADA no se elimina ni se reutiliza su número.

### RF-05 — Anulación de facturas

Anular con motivo, fecha, usuario y bitácora. No eliminar factura, recibos, pagos ni movimientos. Excluir factura anulada de cuentas por cobrar y ventas vigentes, según tratamiento contable documentado. **Regla conservadora propuesta para la primera iteración:** si tiene pagos registrados, entregas o devoluciones, **bloquear anulación automática** hasta que existan operaciones explícitas de reversión/devolución y autorización del administrador. No simular que devolver dinero es lo mismo que cancelar una factura.

### RF-06 — Acciones adaptativas, sin duplicados

Estados de **cobro** y **entrega** son independientes:

- `Sin pagos`: botón `Cobrar`.
- `Abonada`: botón `Registrar abono` o `Cobrar saldo`; mostrar abonado y saldo restante.
- `Cobrada totalmente`: etiqueta/acción desactivada `Cobrada` con comprobación en servidor de que saldo = 0.
- `Pendiente de entrega`: permitir entregar sujeto a reglas de stock y permisos.
- `Entregada`: etiqueta/acción desactivada `Entregada`; no duplicar movimientos.
- `Anulada`: bloquear acciones incompatibles.

El botón desactivado **no es suficiente**; probar solicitudes repetidas, simultáneas y reintentos.

### RF-07 — Iniciales, abonos, cuotas y saldo

Registrar tantos abonos como corresponda, cada uno con `id`, factura, monto, método, fecha, usuario, número de recibo y clave de idempotencia. Distinguir `Inicial` como etiqueta de pago inicial, no como otro tipo de ingreso. Historial cronológico y recibos individuales; total pagado y saldo son derivados de pagos efectivos y reversos autorizados.

- `Sin pagos`: pagado 0, saldo total.
- `Parcial`: 0 < pagado < total.
- `Saldada`: pagado == total.
- `Pagada con múltiples abonos`: contar pagos efectivos >= 2, esté o no saldada.
- **Aclaración:** “varios abonos” no equivale a un plan formal de cuotas con fechas programadas; calendario de cuotas queda PENDIENTE de confirmación.

KPIs: número de facturas parciales, total pendiente de esas facturas, facturas saldadas en varios pagos, entradas de efectivo del día/mes, facturas sin pago, último pago y su fecha.

### RF-08 — Listado compacto estilo Excel

Reemplazar tarjetas voluminosas por filas de máximo **dos líneas de información**, con detalles ampliables al tocar la fila. Optimizado para Android. Mantener información esencial: número, fecha, total, saldo, estado de cobro, estado de entrega. Filtros: **Todas | Por cobrar | Con abonos | Cobradas | Por entregar | Anuladas**. Filtros opcionales posteriores: búsqueda texto, fechas, montos, usuario y orden.

Ejemplo esquemático (NO diseño final):

```text
FAC-0041  14/10  RD$ 3,500      [···]
Abonado: 2,200 · Saldo: 1,300  [Abonar]
--------------------------------------
FAC-0040  13/10  RD$ 2,800      [···]
Cobrada ✓ · Pendiente entrega   [Entregar]
--------------------------------------
FAC-0039  12/10  RD$ 1,750      [···]
Por cobrar · Entregada ✓        [Cobrar]
```

Las acciones que ya no aplican aparecen desactivadas o como etiquetas informativas; botón de menú secundario para ver documento, historial de pagos, anulaciones y detalles. Asegurar buena legibilidad y áreas táctiles suficientes. Evitar una tabla horizontal que obligue a desplazamiento lateral en móvil.

### RF-09 — Renombre de calculadoras

El usuario solicita nombres **más técnicos y exclusivos**. Opciones PROVISIONALES a aprobar:

- `Calculadora A / Cocina A` → **Planificación de Producción** (rendimiento, lotes, cantidades, compras, sobrantes).
- `Calculadora B / Costos B` → **Costeo y Rentabilidad** (empaques, adicionales, precios, márgenes, ganancias).

Mantener internamente `calculator` y `costs` al inicio para minimizar roturas; actualizar nombres visibles, menú, títulos, textos auxiliares y documentación. **Aprobar denominaciones antes de fijarlas como definitivas.**

---

## 4. Arquitectura v0.8 propuesta (por implementar; NO existente)

```text
Android A (ADMIN)                        Android B (OPERADOR)
┌──────────────────────┐                ┌──────────────────────┐
│ BOBC APK 0.8         │                │ BOBC APK 0.8         │
│ UI HTML/CSS/JS       │                │ UI HTML/CSS/JS       │
│ borradores + cache   │                │ borradores + cache   │
│ cifrada              │                │ cifrada              │
└──────────┬───────────┘                └──────────┬───────────┘
           └──────── HTTPS / Auth / Realtime ─────┘
                              │
                ┌─────────────▼─────────────┐
                │ Backend privado (propuesta)│
                │ Supabase Auth + PostgreSQL │
                │ RLS + funciones/RPC        │
                │ auditoría + backups        │
                └───────────────────────────┘
```

**Propuesta técnica:** Supabase con PostgreSQL y Auth (servicio de terceros a contratar/configurar; costos y límites deben verificarse al implementar). El servidor pasa a ser **fuente de verdad** de documentos emitidos, pagos y entregas. Los dispositivos conservan caché local de lectura y borradores; el servidor valida cada operación crítica con transacciones atómicas. Implementar RLS por `business_id` y tabla de membresía. Realtime o sincronización por versiones/pull tras conexión. No crear credenciales ni servicios usando secretos inventados.

**Offline inicial (diseño conservador):** permitir consultar caché y crear/editar borradores localmente; **emitir facturas, confirmar pagos, entregar inventario o anular requieren conexión** hasta que exista una cola offline transaccional probada. La prioridad es evitar doble cobro, exceso de saldo y existencias inconsistentes. La decisión de permitir operaciones finales sin internet queda por aprobar.

**Uso de web/PWA:** el contenido web `docs/` servido públicamente no debe acceder a funciones privadas por sí solo. No introducir secretos de backend en código web público, ni exponer credenciales `service_role` en APK, JavaScript o GitHub. Una clave publicable de proyecto **no autoriza datos**: RLS y tokens de cada usuario deben cubrir cada lectura/escritura.

---

## 5. Modelo relacional propuesto (versión lógica v0.8)

Este listado es un **contrato inicial**, no migraciones SQL ejecutadas. Codex debe producir DDL y migraciones idempotentes, relaciones FK, índices y policies RLS y verificarlas con tests. Todos los registros de negocio deben incluir `business_id` cuando aplique.

| Entidad | Campos principales | Notas/constraint |
|---|---|---|
| `businesses` | `id uuid PK`, `display_name`, `currency='DOP'`, `created_at` | un negocio inicialmente |
| `memberships` | `business_id`, `user_id` (Auth UID), `role` (`admin`,`operator`), `active`, timestamps | `UNIQUE(business_id,user_id)`, RLS |
| `products` | `id`, `business_id`, `name`, `variant`, `active`, timestamps, `legacy_id` | compatible con catálogo v0.7 |
| `recipes` | `id`, `business_id`, `product_id`, `version`, `yield_ml`, `extra_ml`, `ingredients_json`, timestamps, `legacy_id` | no alterar fórmula histórica |
| `skus` | `id`, `business_id`, `product_id`, `size_ml`, `tier`, precios/costos en centavos, `legacy_id` | presentación terminada |
| `quote_drafts` | `id`, `business_id`, `created_by`, `updated_by`, `version`, `payload_json`, timestamps | editable; nunca número definitivo |
| `quotes` | `id`, `business_id`, `number`, `status`, `total_cents`, `lines_json` o tabla, `snapshot_json`, `issued_by`, `issued_at`, `cancelled_at`, `cancel_reason`, `source_draft_id`, `legacy_id` | histórico y trazable |
| `invoice_drafts` | `id`, `business_id`, `source_quote_id?`, `created_by`, `version`, `payload_json` | editable hasta emitir |
| `invoices` | `id`, `business_id`, `number`, `source_quote_id?`, `status`, `total_cents`, `snapshot_json`, `issued_at`, `issued_by`, `cancelled_at`, `cancel_reason`, `legacy_id` | número único por negocio; no borrar |
| `invoice_lines` | `id`, `invoice_id`, `sku_id?`, `description_snapshot`, `qty`, `unit_price_cents`, `total_cents` | congelar descripción/precio al emitir; artículo manual opcional solo si validado |
| `payments` | `id`, `business_id`, `invoice_id`, `receipt_number`, `amount_cents`, `method`, `payment_label` (`initial`,`installment`,`final`,`standard`), `paid_at`, `created_by`, `idempotency_key`, `reversed_at?` | monto positivo; ingreso una sola vez |
| `deliveries` | `id`, `business_id`, `invoice_id`, `status`, `delivered_at`, `created_by`, `idempotency_key` | sin doble entrega; detalle parcial en fase posterior |
| `stock_movements` | `id`, `business_id`, `sku_id`, `kind`, `qty_delta`, `source_type`, `source_id`, `created_by`, `created_at` | asiento por evento, vínculo único |
| `supplies` / `supply_movements` | datos legacy y `business_id`, `legacy_id` | material de empaque independiente |
| `expenses` | `id`, `business_id`, `date`, `name`, `category`, `amount_cents`, `created_by`, `legacy_id` | conservar gastos |
| `documents` | `id`, `business_id`, `kind`, `ref_id`, `number`, `snapshot_json`, `created_at` | recibo/cotización/factura históricos |
| `audit_log` | `id`, `business_id`, `actor_user_id`, `action`, `entity_type`, `entity_id`, `before_json?`, `after_json?`, `reason?`, `created_at` | append-only, no exponer secretos |
| `idempotency_operations` | `business_id`, `operation_key`, `operation_type`, `result_ref`, `created_at` | clave única; solicitudes repetidas devuelven mismo resultado |
| `migration_batches` | `id`, `business_id`, `source_device`, `source_schema`, `file_checksum`, `imported_by`, `created_at`, `status` | migración revisable |
| `legacy_id_map` | `migration_batch_id`, `entity_type`, `legacy_id`, `server_id` | deduplicación origen + ID |

**Tipos de datos e invariantes:**

- `id` UUID; hora UTC ISO para almacenamiento, convertir a hora local en UI; fecha de documento y número preservados al migrar.
- `amount_cents`/`total_cents` enteros (`BIGINT` o equivalente) y nunca flotantes binarios en el cálculo de dinero.
- `receipt_number`, `quote.number`, `invoice.number`: únicos por negocio y tipo de documento (secuencias transaccionales). No reutilizar números de anulados; números de borradores temporales distintos.
- `payments` no se borran; revertir exige entrada/estado auditado. Saldo = factura emitida vigente – pagos efectivos netos. Nunca negativo.
- `invoices.source_quote_id`: conservar origen; unicidad por cotización solo mientras se mantenga la regla de 1 factura por cotización.
- `documents.snapshot_json`: no alterar al cambiar catálogo o precios.
- `deliveries` y `stock_movements`: deduplicar por operación/fuente; devolver stock solo mediante movimiento inverso autorizado, no borrando filas.
- Separar estado de documento (`draft`, `issued`, `cancelled`) de estado de cobro (`unpaid`, `partial`, `paid`) y estado de entrega (`pending`, `delivered`). Los últimos pueden ser vistas derivadas.
- Configurar índices por `business_id, issued_at`, `business_id,status`, `invoice_id`, `source_quote_id`, `created_by`, `idempotency_key`.
- Las tablas provisionales de borrador pueden consolidarse como `document_drafts` con `document_type`, si facilita la implementación sin perder seguridad.

### 5.1 Ejemplo de contrato JSON de pantalla (ilustrativo)

```json
{
  "invoice_id": "uuid-de-ejemplo",
  "number": "FAC-000041",
  "document_status": "issued",
  "total_cents": 350000,
  "paid_cents": 220000,
  "balance_cents": 130000,
  "payment_status": "partial",
  "payment_count": 2,
  "delivery_status": "pending",
  "can_record_payment": true,
  "can_deliver": true,
  "can_void": false
}
```

Los booleanos `can_*` deben derivarse de permisos **y** reglas de negocio; el backend debe repetir las validaciones.

---

## 6. Operaciones críticas: contratos atómicos

Codex debe implementar endpoints o RPC transaccionales; NO confiar en una cadena de escrituras cliente que pueda interrumpirse entre pasos.

- `issue_quote(draft_id, draft_version, idempotency_key)`: validar rol y líneas, calcular total servidor, asignar número, crear snapshot, marcar borrador emitido, registrar auditoría. Repetir misma clave → mismo resultado; no crear duplicado.
- `create_invoice_draft_from_quote(quote_id)`: validar cotización emitida y no anulada; copiar líneas y condiciones en nuevo borrador editable, mantener origen; no emitir aún.
- `issue_invoice(invoice_draft_id, version, idempotency_key)`: validar rol/stock si aplica/regla de conversión, asignar número y snapshot, vincular cotización, estado emitida, auditar. Dos solicitudes simultáneas → una factura.
- `record_payment(invoice_id, amount_cents, method, label, idempotency_key)`: transacción con bloqueo sobre factura/total efectivo, prohibir anuladas, cantidad `>0` y `<=saldo`, crear pago, recibo y bitácora, responder nuevo saldo. Solicitud repetida → mismo recibo.
- `confirm_delivery(invoice_id, items?, idempotency_key)`: prohibir entrega doble, aplicar movimientos de inventario *exactamente una vez*, registrar actor/fecha/documento. Para v0.8 inicial la entrega es completa; entregas parciales son mejora posterior salvo nueva aprobación.
- `void_quote(quote_id, reason, idempotency_key)`: solo rol autorizado, bloquear si convertida, estado anulada y auditoría.
- `void_invoice(invoice_id, reason, idempotency_key)`: solo rol autorizado; bloquear si pagos/entrega mientras no esté implementado el proceso de reversión o devolución aprobada; mantener documento y número.

**Prevenir doble efecto:** restricciones DB `UNIQUE` y transacciones/locks + `idempotency_key` en servidor, además de UI que deshabilita acciones pendientes. No confiar en `localStorage`, timers o un solo teléfono.

### 6.1 Caso de aceptación numérico

Factura `FAC-0041`, `total_cents = 350000` (RD$3,500):

1. Inicial RD$1,000 → abonado RD$1,000; saldo RD$2,500; 1 recibo.
2. Segundo abono RD$1,200 → abonado RD$2,200; saldo RD$1,300; 2 recibos.
3. Pago final RD$1,300 → abonado RD$3,500; saldo RD$0; 3 recibos.
4. Intentar registrar RD$1 adicional → **rechazado servidor**; UI muestra `Cobrada` desactivado.
5. Entregar una sola vez → `Entregada` desactivado; no duplicar movimiento de inventario.
6. La factura queda identificada como **saldada mediante tres pagos**, distinta de otra factura pagada de contado.

---

## 7. Seguridad Android y nube (objetivos de diseño)

### 7.1 Identidad, sesión y autorización

- Inicio de sesión único por usuario con proveedor Auth configurado y verificación de correo u otro mecanismo acordado. No compartir misma contraseña entre usuarios.
- Roles en `memberships`; RLS por negocio, `auth.uid()` y `active`. Deshabilitar registro público/invitaciones externas no autorizadas.
- Biométrico/PIN del teléfono como **bloqueo local adicional**, no reemplazo de identidad de nube. Bloquear tras inactividad y al volver de segundo plano según regla acordada.
- Expiración/renovación segura de tokens; revocación efectiva de cuentas; proteger almacenamiento del token.
- HTTPS/TLS en todas las comunicaciones; restringir orígenes; no usar secretos de servicio en cliente.

### 7.2 Datos en reposo y backups

- La base compartida debe tener controles de permisos, respaldo y cifrado en el proveedor. No afirmar cifrado extremo a extremo si el backend debe procesar valores.
- En Android cifrar la persistencia sensible/caché local con clave gestionada mediante **Android Keystore**; definir implementación real según arquitectura (p. ej. almacenamiento nativo cifrado/SQLCipher o cifrado autenticado de registros antes de IndexedDB). Una simple cadena Base64 o `localStorage` no es cifrado.
- Exportar respaldo **cifrado con contraseña de recuperación**, con KDF resistente (Argon2id o alternativa validada disponible) y AES-256-GCM; incluir versión, sal/nonce, integridad y guía de recuperación. No exportar JSON legible por defecto sin advertencia explícita.
- Evitar exponer archivos temporales; descargas de respaldos cifrados; compartir PNG de comprobantes sigue siendo una acción deliberada del usuario (su contenido no estará cifrado al compartirse).
- Política de Android Backup: deshabilitar/excluir las bases no cifradas y credenciales; configurar `dataExtractionRules`/`fullBackupContent` según versión Android. No confundir backup en nube de Android con respaldo portable entre equipos.

### 7.3 Endurecimiento de WebView/bridge

- Revisar `MainActivity.java` y `AndroidManifest.xml`: limitar cargas a recursos locales confiables, bloquear scripts remotos/no autorizados, abrir enlaces externos fuera del WebView sin exponer el bridge, denegar navegación arbitraria, CSP cuando corresponda.
- Auditar `BOBCAndroid` y `@JavascriptInterface` para que solo puedan invocarse desde contenido confiable; sanitizar nombre/tipo/tamaño de archivos; límites de tamaño para Base64; no permitir rutas arbitrarias.
- Permisos Android mínimos; sin almacenamiento amplio si `MediaStore`/SAF resuelven las exportaciones.
- Opción de `FLAG_SECURE` para pantallas privadas, con revisión de usabilidad; ocultar vistas al cambiar de aplicación si se aprueba.
- Firma Android persistente: generar keystore **privado fuera del repositorio**, almacenar bajo custodia del propietario / secretos CI bien protegidos; `versionCode > 71`, `applicationId` fijo para futuras actualizaciones. Como la APK 0.7.1 usó una clave debug de CI, **la nueva firma puede exigir desinstalación y reinstalación**: respaldar, comprobar restauración y luego cambiar; jamás decir al usuario que desinstale sin respaldo verificado.

### 7.4 Advertencia de privacidad

El repositorio GitHub del proyecto es **público**. No subir clientes reales, facturas reales, contraseñas, exportaciones JSON, claves privadas, tokens, APK con secrets incrustados ni registros de ambos usuarios. Usar datos ficticios en fixtures y tests.

---

## 8. Migración desde BOBC 0.7.1 sin pérdida de datos

**Problema de partida:** hoy cada móvil tiene datos **locales e independientes**; ambos podrían tener registros coincidentes, diferentes o números repetidos. La versión Universal v1.0 usó `schema:2` en la misma base web en ciertos casos. La versión 0.7.1 de recuperación permite `state-v07-restaurada`; **conservarla**.

**Secuencia obligatoria:**

1. Fijar rama base y commit existente de `android-bobc-07/` antes de tocar código.
2. Exportar respaldo de **cada uno de los dos dispositivos** (no asumir que un solo respaldo contiene todo). Guardar copia inmutable y checksum SHA-256; confirmar que sea legible y recuperable.
3. Generar entorno de prueba con datos inventados y respaldos sanitizados. Nunca subir datos reales al repositorio público.
4. Implementar importador que detecte `schema=1` y diferencie `state` vs `state-v07-restaurada`; *no convertir, borrar ni sobrescribir automáticamente* la base `schema=2` Universal.
5. Crear inventario/preview previo a migración: cantidad de productos, recetas, SKUs, cotizaciones, facturas, pagos, recibos, movimientos, gastos, existencias; detectar IDs y números duplicados entre dispositivos.
6. Mapear `legacy_id` → UUID de servidor por `migration_batch_id` y `source_device_id`. Mantener fecha/número originales cuando sea seguro; resolver colisiones de forma documentada sin falsificar numeración histórica.
7. Migrar primero catálogo/recetas/SKUs, luego documentos, facturas, pagos y movimientos. Comprobar suma de pagos, saldos, existencias, vínculos y snapshots.
8. Ejecutar migración **idempotente**: importar dos veces el mismo archivo no genera duplicados.
9. Pedir confirmación del administrador después de mostrar comparación antes/después. No eliminar bases locales antiguas.
10. Confirmar sincronización ambos móviles, restauración, revocación y recuperación antes de considerar migración terminada.

**Firma y datos actuales:** no asumir actualización directa sobre APK debug de 0.7.1 al usar keystore persistente nuevo. Proporcionar asistente de respaldo/restauración antes de cualquier reinstalación.

**Criterios de integridad:** conteo y sumas idénticos antes/después para cada entidad; cero pagos huérfanos; cero recibos duplicados; cero stock restado dos veces; cotizaciones/facturas históricas inalteradas. Los errores deben reportarse y detener migración, no corregirse silenciosamente.

---

## 9. UX/UI solicitada para móvil

- Mantener fondo claro y paleta pastel aprobada.
- Menú lateral y navegación inferior; no rehacer estética completa ni agregar frameworks innecesarios.
- Listado de facturas de **una o dos líneas** por registro; indicar estados con texto legible, no solo colores.
- Acciones al lado, idealmente 1 principal y menú `···` con el resto; botones fáciles de tocar.
- Vista de detalle separada: encabezado + líneas + historial de abonos + saldo + documentos + entrega + anulación según rol.
- Formularios en modalidad **BORRADOR** con etiqueta explícita y botón `Emitir` solo tras pantalla de confirmación.
- Si un usuario toca `Cobrar` y otro termina de saldar primero, refrescar estado y mostrar `La factura ya está cobrada`, no duplicar pago.
- Indicador de conexión y última sincronización; borradores offline visibles; indicar fallos y reintentos.
- Estados vacíos útiles y mensajes de validación específicos.

**Diseño modular:** separar vista (`ui_v06.js` o reemplazos acotados), lógica de negocio compartida, almacenamiento sincronizado, autenticación y adaptadores nativos; evitar lógica financiera duplicada entre UI y backend.

---

## 10. Plan de desarrollo por fases para Codex

**Regla transversal:** una fase = cambios pequeños revisables + tests + demo + resumen de archivos afectados. No declarar éxito solo porque Gradle compiló. No publicar ni reemplazar `main` ni APK estable sin aprobación y pruebas.

### FASE 0 — Diagnóstico y congelación

- Inspeccionar repo, identificar versión 0.7.1 real y enumerar dependencias/rutas completas.
- Crear rama de trabajo `feature/bobc-0.8-private-sync` desde el estado estable y preservar `bobc-1.0-artesanal-universal`.
- Elaborar inventario de entidades, flujos, puntos de escritura e invariantes; registrar defectos preexistentes.
- Preparar fixtures sintéticos, suite de regresión y ruta de exportación/recuperación.

### FASE 1 — Refactor local comercial (sin nube todavía)

- Implantar borradores cotización/factura, previsualización, edición y confirmación.
- Añadir anulación trazable con bloqueos seguros para documentos con cobros/entregas.
- Introducir estado derivado de cobro y entrega; desactivar botones incompatibles.
- Nuevo listado compacto y filtros.
- Historial y KPIs de abonos; preservar recibos.
- Renombrado provisional documentado o condicionado a aprobación.
- Tests de regresión sin cambiar servidor ni destruir datos.

### FASE 2 — Backend privado, permisos y transacciones

- Crear proyecto de backend bajo control del usuario, esquema/migraciones, Auth, roles, RLS y auditoría.
- Crear funciones atómicas para emitir, cobrar, entregar y anular con idempotencia.
- Probar RLS negativo: un usuario sin membresía jamás puede leer o escribir el negocio.
- Implementar servicio cliente desacoplado y fallos bien manejados.

### FASE 3 — Sincronización dual y migración

- Añadir autenticación a ambas APK, bootstrap del negocio y segunda cuenta.
- Migrar respaldos de ambos dispositivos con preview, deduplicación y validación de saldos/stock.
- Sincronizar cambios, manejar reintentos, desconexiones y cambios simultáneos.
- Admitir lectura offline y borradores; bloquear operaciones finales sin internet según política conservadora.

### FASE 4 — Seguridad Android y firma

- Cifrado local y recuperación, biometría/PIN, permisos mínimos, WebView bridge hardened.
- Crear y custodiar keystore permanente, pipeline de APK release firmado con secretos; documentar actualización desde debug.
- Pruebas de instalación, actualización, exportación/restauración, revocación de usuarios y reconexión.

### FASE 5 — QA final y entrega

- Compilar APK de pruebas y después release privada firmada si existe keystore persistente.
- Revisar dashboard, cocina, costos, productos, cotizaciones, facturas, pagos, recibos, documentos, inventario, gastos, backup y sincronización en **dos celulares reales**.
- Guardar reportes con resultados verificables: casos probados, fallos, riesgos y versión exacta/commit/hash APK.
- Sólo después de aceptación explícita: presentar nueva APK como reemplazo de 0.7.1.

---

## 11. Matriz QA y criterios de aceptación mínimos

| ID | Caso / entrada | Resultado requerido |
|---|---|---|
| QA-001 | Instalar v0.8 desde entorno limpio | login seguro y dashboard sin fallo |
| QA-002 | Crear usuario admin y operador | ambos ven mismo negocio, roles distintos |
| QA-003 | Operador intenta gestión de usuarios | backend rechaza operación |
| QA-004 | Administrador revoca cuenta | pierde acceso incluso con APK instalada (según política de sesiones) |
| QA-005 | Cocina A ejemplo: receta + botellas | rendimiento/ingredientes/sobrantes iguales a 0.7.1 |
| QA-006 | Costos B: envases/etiquetas/margen | resultados comparables a 0.7.1, sin redondeos erróneos |
| QA-007 | Costos → Cotizar | solo borrador, no emite automáticamente |
| QA-008 | Editar borrador y emitir cotización | totales recalculados y documento snapshot correcto |
| QA-009 | Cotización → Factura | borrador editable, no factura emitida automáticamente |
| QA-010 | Editar factura y confirmar | factura emitida una sola vez, vínculo con cotización intacto |
| QA-011 | 2 intentos simultáneos emisión misma cotización | solo 1 factura o rechazo coherente |
| QA-012 | Anular cotización válida | número/historial conservados y no convertible |
| QA-013 | Anular factura sin pagos/entrega | historial conservado, saldo no activo |
| QA-014 | Intentar anular factura con pago/entrega | bloquea o exige proceso de reverso aprobado |
| QA-015 | Cobrar RD$1,000+1,200+1,300 de factura RD$3,500 | tres recibos, saldo 0, ingresos RD$3,500 |
| QA-016 | Cobrar de nuevo una factura saldada | UI `Cobrada`, servidor rechaza |
| QA-017 | Entregar factura una vez | `Entregada` + un solo movimiento stock |
| QA-018 | Entregar por segunda vez | UI desactivada y servidor rechaza doble consumo |
| QA-019 | Factura cobrada pero no entregada | ambos estados correctos e independientes |
| QA-020 | Factura entregada pero no cobrada | ambos estados correctos e independientes |
| QA-021 | Listado con al menos 50 facturas | filas compactas, filtros/búsqueda, scroll móvil adecuado |
| QA-022 | Filtrar `Con abonos` vs `Cobradas en múltiples pagos` | conjuntos correctos |
| QA-023 | Ambos teléfonos pagan misma factura simultáneamente | ningún sobrepago y sin duplicar recibo |
| QA-024 | Reintento de petición con misma idempotency_key | misma respuesta, ningún asiento adicional |
| QA-025 | Desconexión y reconexión | caché/borrador conservados, posterior sincronización |
| QA-026 | Intentar acceso sin ser miembro del negocio | RLS impide leer/escribir |
| QA-027 | Importar dos veces respaldo legacy | sin duplicados y conteos correctos |
| QA-028 | Migrar dos teléfonos con IDs/números colisionados | reporte/conciliación sin sobrescritura silenciosa |
| QA-029 | Exportar respaldo cifrado → restaurar en otro dispositivo | datos íntegros con contraseña correcta; contraseña incorrecta falla |
| QA-030 | Documento PNG compartido / impresión | salida correcta sin permiso de acceso excesivo |
| QA-031 | APK firmada y actualización sobre build previo | firma y versión verificadas; migración/instalación documentadas |
| QA-032 | Dashboard ingresos/saldos tras anulación | importes correctos, sin duplicaciones |

**Criterio de terminación:** pruebas verdes reales (no inventar % de éxito), matriz de cobertura, prueba de migración reversible, revisión de seguridad y aprobación del propietario. Controles financieros se prueban en backend además de UI.

---

## 12. Decisiones pendientes: no inventar

| D-# | Decisión | Opción conservadora mientras se aprueba |
|---|---|---|
| D-01 | ¿El OPERADOR puede anular cotizaciones/facturas? | No, solo ADMIN |
| D-02 | ¿Qué hacer con facturas pagadas/entregadas antes de anular? | Bloquear anulación hasta flujo de reversión/devolución aprobado |
| D-03 | ¿Cuáles campos de borrador serán editables? | Líneas, cantidad, precios, descuento, entrega, envío y notas con auditoría |
| D-04 | ¿Cómo se llamarán definitivamente los módulos A/B? | Planificación de Producción; Costeo y Rentabilidad (provisional) |
| D-05 | ¿Se pueden emitir/cobrar/entregar sin internet? | No; solo lectura y borradores offline inicialmente |
| D-06 | ¿Habrá calendario de cuotas con vencimientos? | No; inicialmente solo registro real de inicial/abonos |
| D-07 | ¿Se permitirán entregas parciales? | No inicialmente, conservar entrega total |
| D-08 | ¿Se emitirán documentos fiscales DGII/NCF? | No; uso comercial privado hasta nuevo requerimiento específico |
| D-09 | ¿Qué backend/proveedor final y presupuesto? | Supabase propuesto, no contratado ni configurado |
| D-10 | ¿Quién guarda el keystore y contraseña de respaldo? | Propietario; jamás dentro de GitHub ni en texto plano en Codex |
| D-11 | ¿Se migrará la PWA de Chrome además de las APK? | APK privada primero; PWA pública no tiene acceso al backend privado por defecto |

---

## 13. Instrucciones de operación para Codex (lectura obligatoria)

1. Abrir `https://github.com/jcarlospm05/Sistema-Artesanal-Android` y localizar el código `android-bobc-07/`. No modificar `bobc-1.0-artesanal-universal`, no mezclar con arquitectura corporativa ni CRM aparte.
2. Verificar la **versión real en GitHub** al iniciar la sesión y el historial de cambios. El presente documento es una foto de requisitos a 14/10/2026, no una garantía de que no existan cambios futuros.
3. Leer `app.js`, `ui_v06.js`, `cocina_a.js`, `costos_b.js`, `MainActivity.java`, `AndroidManifest.xml` y workflow antes de refactorizar.
4. Comenzar por **FASE 0**: emitir un breve diagnóstico, lista de módulos tocados, plan de migración y riesgos. No implementar 0.8 entera en un único commit.
5. Trabajar en rama `feature/bobc-0.8-private-sync`; cambios pequeños y reversibles; generar diff, tests, evidencias y estado por fase.
6. Conservar todas las operaciones v0.7.1, paleta aprobada, redondeos y recibos. No introducir clientes obligatorios ni confundir el MVP con BOBC Universal.
7. Ningún pago, anulación o entrega debe hacerse exclusivamente en lógica del navegador o con un simple flag. Exigir transacción en servidor una vez añadido el backend.
8. No insertar en el repositorio público datos reales, credenciales, tokens o keystores.
9. No sustituir APK del usuario ni aconsejar desinstalar sin respaldo y restauración probados.
10. Al final de cada fase: entregar archivos modificados, pruebas ejecutadas, riesgos y acciones que faltan. **No afirmar “listo” sin build y QA apropiados.**

### Prompt sugerido para iniciar una tarea nueva en Codex

> Estoy desarrollando **BOBC Taller Artesanal 0.8**, partiendo de la APK 0.7.1 en `android-bobc-07/`. Lee íntegramente `DATASHEET_BOBC_0.8_PARA_CODEX.md`, inspecciona el repositorio y **NO edites la versión Universal ni reemplaces `main`**. Empieza solo por **FASE 0: auditoría del código existente, inventario de dependencias, riesgos y plan de migración**, indicando las decisiones pendientes antes de modificar datos o facturación. Después proponme el primer commit de FASE 1 con sus tests y espera mi aprobación para integrarlo. Mantén sin cambios todas las funciones existentes de cocina, costos, inventario y documentos.

---

## 14. Entregables finales esperados de Codex

- APK BOBC 0.8 con firma persistente (una vez que se configure keystore), identidad y versión correctas.
- Documentación de instalación/actualización desde debug 0.7.1 sin pérdida de datos.
- Migraciones SQL, RLS, auditoría, funciones transaccionales y tests de permisos/concurrencia.
- Contrato JSON/API de cobros, facturas, cotizaciones, entregas y estados.
- Diseño compacto de facturas + borradores editables + anulación con trazabilidad.
- Mecanismo de sincronización de dos teléfonos, estados offline claros y migrador reversible.
- Respaldo cifrado y prueba real de recuperación.
- Matriz de QA, bitácora de versiones, reporte de riesgos y checksum de APK.

**FIN DEL DATASHEET — BOBC 0.8.**