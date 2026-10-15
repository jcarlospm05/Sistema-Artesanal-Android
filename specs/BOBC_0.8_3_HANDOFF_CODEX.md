# BOBC SOFTWARE — DATASHEET TÉCNICO MAESTRO / HANDOFF A CODEX

> **Producto:** BOBC · Taller Artesanal — Gestión de producción y operaciones comerciales de ponches artesanales  
> **Versión base auditada:** BOBC **0.8.3 Sync Beta** (Android, WebView + HTML/CSS/JS, Supabase Auth + PostgreSQL)  
> **Fecha de corte:** 15 de octubre de 2026  
> **Propósito:** continuar en Codex el desarrollo, endurecimiento, pruebas e instalación sin perder funciones existentes.  
> **Estado:** BETA FUNCIONAL COMPILADA, **NO** RELEASE FINAL DE PRODUCCIÓN. La sincronización existe, pero quedan pruebas y controles importantes.  
> **Naturaleza del documento:** fotografía del código y de Supabase contrastada con las especificaciones anteriores; lo *propuesto* está distinguido de lo *implementado*.

---

## 0. Instrucción prioritaria para Codex

Trabajar sobre **el producto BOBC Taller Artesanal**, no sobre el producto independiente BOBC Artesanal Universal. Clonar el repositorio, inspeccionar la rama actual, verificar base de datos y pruebas y continuar desde la realidad del código. **No reconstruir BOBC desde cero**, no sustituir lógica comercial estable sin pruebas ni introducir cambios irreversibles en registros existentes. El propietario autorizó continuar el desarrollo sin solicitar aprobación para decisiones técnicas ordinarias; ello **no** autoriza eliminar datos reales, filtrar claves, cambiar cuentas o firmas de aplicaciones instaladas ni desplegar operaciones destructivas sin salvaguardas.

### Referencias exactas

| Recurso | Referencia |
|---|---|
| Repositorio | `https://github.com/jcarlospm05/Sistema-Artesanal-Android` |
| Rama de trabajo | `feature/bobc-0.8-private-sync` |
| Commit de código verificado al corte | `2e498c6821e8688e676690489f4cc6b470939f0a` |
| Rama estable — **no modificar** | `main` (BOBC 0.7.1) |
| Rama universal — **no modificar** | `bobc-1.0-artesanal-universal` |
| Directorio Android | `android-bobc-07/` |
| Archivos web empaquetados | `android-bobc-07/app/src/main/assets/www/` |
| Datasheet anterior, **histórico** | `specs/BOBC_0.8_DATASHEET_CODEX.md` (encabezado desactualizado: afirma que aún no se compiló) |
| Estado de Beta actual | `specs/BOBC_0.8_SYNC_BETA_ESTADO.md` |
| Permisos de operadora | `specs/BOBC_0.8_PERFIL_OPERADORA.md` |
| Configuración DB | `supabase/migrations/*.sql` |
| Supabase proyecto | `BOBC-PRIVATE` — ID `tsjbizuoxorebvccwmig` |
| URL pública de API | `https://tsjbizuoxorebvccwmig.supabase.co` |
| GitHub Actions de la Beta compilada | `https://github.com/jcarlospm05/Sistema-Artesanal-Android/actions/runs/38667514687` (éxito) |

**Nota de seguridad:** la URL y la clave *publishable* de Supabase no son secretos. Las contraseñas, claves `service_role`/`secret`, tokens de sesión y keystore privado **sí** son secretos: nunca subirlos al repositorio ni al datasheet. La rama es pública; el datasheet **no** registra correos particulares ni contraseñas.

---

## 1. Objetivo funcional del producto

BOBC es una aplicación privada para **dos dispositivos Android y un negocio**. Ambos usuarios deben ver el mismo estado de operaciones: productos y fórmulas, ingredientes, envases y presentaciones, inventario terminado, materiales, cálculos de producción y costos, cotizaciones, borradores, facturas, cobros iniciales/abonos, recibos, entregas, gastos, documentos y panel gerencial.

- Idioma: **español**; moneda **DOP / RD$**; importes almacenados en **centavos enteros**.
- Negocio: ponches/productos artesanales. No agregar por defecto un módulo obligatorio de clientes.
- Comercial: documentos **privados no fiscales**; no afirmar que son comprobantes DGII ni incluir NCF sin requisitos propios.
- Interfaz: uso Android-first, menú lateral, navegación inferior, lista compacta de facturas, flujo revisable, recibos compartibles por WhatsApp como PNG.
- Usuarios: un **administrador** y una **operadora comercial y producción**; arquitectura permite otros perfiles.
- Alcance actual: aplicaciones en ambos celulares con datos comerciales compartidos por Supabase, **operaciones que modifican registros solo con internet**.

### Funciones de cálculo que no se deben romper

**Planificación de Elaboración** (antigua Calculadora A; `cocina_a.js`): rendimiento, volumen base/adicional, lotes, cantidades y presentaciones, compras, distribución por botellas, excedentes. **Costeo y Rentabilidad** (antigua Calculadora B; `costos_b.js`): costo de ingredientes, envases, etiquetas, costos unitarios, precio y margen, enlace a documentos comerciales. Mantener reglas numéricas, información original de recetas y cálculos existentes.

---

## 2. Estado verificado, no supuesto

### 2.1 Android / integración

**Implementado en GitHub (commit anterior):**
- APK `versionName '0.8.3-sync-beta'`, `versionCode 83`, `applicationId 'com.bobc.artesanal.sync08'`.
- `minSdk 26` (Android 8+), `targetSdk 33`, `compileSdk 35`, Java 17, Gradle 8.10.2, `androidx.webkit:webkit:1.12.1`.
- `WebViewAssetLoader` para HTML/CSS/JS empaquetado en HTTPS local (`appassets.androidplatform.net`).
- Android `INTERNET` habilitado, `usesCleartextTraffic=false`, `allowBackup=false`.
- No utiliza el `applicationId` de BOBC 0.7.1; las versiones pueden coexistir.
- APK compilada y verificable en GitHub Actions (run `38667514687`, resultado **success**). **No equivale a prueba integral en teléfonos físicos.**
- Compilación **debug**; no dispone todavía de firma de producción/actualización persistente.

**No implementado como seguridad final:** cifrado adicional verificable de la base local, biometría/PIN robustos, keystore de release permanente y pruebas de amenazas Android/WebView.

### 2.2 Supabase real consultado a la fecha de corte

Proyecto `BOBC-PRIVATE`, PostgreSQL 17, región `us-east-1`. Existen: un registro `businesses`, una membresía, una invitación pendiente, una fila `bobc_shared_state` con revisión **1** y un evento `bobc_sync_events`; las tablas normalizadas `invoices` y `payments` están vacías. En el JSON compartido se verificaron **0 productos, 0 recetas, 0 cotizaciones, 0 facturas, 0 pagos y 0 movimientos terminados**. Esto coincide con la indicación del propietario de que aún no tiene registros comerciales, aunque **sí existe un snapshot inicial vacío**. No reinicializar ni truncar sin comprobar el estado en la ejecución actual de Codex.

Las migraciones reportadas como aplicadas por Supabase:

1. `bobc_private_foundation`
2. `bobc_users_profiles`
3. `bobc_fix_claim_invitation_ambiguous_business_id`
4. `bobc_operator_commercial_production_permissions`
5. `bobc_shared_sync_atomic`
6. `bobc_sync_validation_hardening`

**Advertencias de auditoría:** `get_advisors(security)` devuelve avisos sobre tablas privadas con RLS sin políticas (cerradas intencionalmente) y funciones `SECURITY DEFINER` ejecutables por autenticados; revisar cada función por seguridad y documentar excepciones justificadas. No conceder acceso anónimo ni desactivar RLS para silenciar el linter.

### 2.3 Precisar el significado de «sincronización terminada»

**Sí hay un mecanismo funcional implementado**, pero es **sincronización de documento completo JSONB por negocio**, no escritura transaccional normalizada a todas las tablas SQL. El backend conserva `state jsonb` + `revision`, aplica validaciones en `bobc_sync_commit`, y los dos clientes hacen `bobc_sync_pull`. El *shell* de la aplicación usa caché IndexedDB. No afirmar que `payments`, `invoices`, `stock_movements` relacionales son actualmente la fuente de verdad: la fuente de verdad en la Beta es **`bobc_shared_state`**. La transición a entidades PostgreSQL individuales es trabajo futuro.

**Estado QA:** pruebas de lógica (`tests/test_logic.js`), sincronización simulada (`tests/test_sync.js`), compilación Gradle y ensayos SQL transaccionales con `ROLLBACK` informados como exitosos. **Pendientes:** pruebas Android reales entre dos teléfonos, envíos de correo/reinstalación, uso bajo pérdida de red, integridad de respaldos, migraciones futuras y pentest básico.

---

## 3. Arquitectura vigente

```text
Android administrador                     Android operadora
  BOBC 0.8.3 sync08                        BOBC 0.8.3 sync08
  WebView HTML/JS                           WebView HTML/JS
  Supabase Auth (sesión propia)             Supabase Auth (sesión propia)
  IndexedDB (caché local)                   IndexedDB (caché local)
              \                             /
               \ HTTPS + JWT + clave publicable
                v
           Supabase · BOBC-PRIVATE
           Auth + memberships + access_profiles + invitaciones
           Postgres + RLS + funciones RPC autenticadas
           bobc_shared_state (state JSONB, revision bigint)
           bobc_sync_events (operación, actor, revisión)
```

**Principio:** el servidor es fuente de verdad. `BOBCSync.start()` consulta el snapshot en el inicio; si no existe, solo el administrador puede crear el inicial. Si existe, se descarga al caché del celular. `BOBCSync.save()` requiere conexión, envía `p_business_id`, `p_revision`, `p_state` y `p_operation_id`; el servidor autoriza y confirma atomicidad. `BOBCSync.refresh()` hace consultas periódicas cada ~10 s y al volver al primer plano, siempre que no esté editando/guardando. Una actualización basada en revisión obsoleta se rechaza (`CONFLICTO_REVISION`). El cliente guarda una copia recuperable antes de restablecer el estado remoto aceptado.

**No es** sincronización offline con cola, ni auto-merge inteligente concurrente, ni realtime push continuo (es *polling*). Evitar describirla como tal.

### 3.1 Archivos clave — respetar contratos existentes

| Ruta (relativa a `android-bobc-07/app/src/main/assets/www/`) | Responsabilidad |
|---|---|
| `app.js` | Estado `schema:1`, IndexedDB, flujos comerciales, formularios, respaldos, inventario, enlace con sincronización |
| `bobc08_sync.js` | Pull/commit CAS, revisión, polling, errores, respaldos de conflicto |
| `bobc08_auth.js` | Supabase Auth, JWT/refresh, activación por invitación, rutas y permisos de UI |
| `bobc08_users.js` | Usuarios y perfiles, autorizar correo, suspender/reactivar, editar perfil |
| `bobc08_core.js` | Estado de factura, abonos, filtros, anulación, protección conversión |
| `ui_v06.js` | Dashboard, listas compactas, formularios/vistas y estados operativos |
| `cocina_a.js` / `costos_b.js` | Planificación, rendimiento, costeo y cálculo |
| `catalog_features.js` / `menu_v07.js` | Formularios producto/receta, menú y navegación |
| `bobc08_supabase_config.js` | URL y clave **publicable** del proyecto; jamás secretos |
| `index.html` / `style.css` | Carga y aspecto Android-first |

Otros: `app/src/main/java/com/bobc/artesanal/MainActivity.java`, `app/src/main/AndroidManifest.xml`, `app/build.gradle`, `.github/workflows/build-bobc-08-preview.yml`, `tests/test_logic.js`, `tests/test_sync.js`.

### 3.2 Estructura de `state` actualmente compartida

Contrato de compatibilidad vigente en app y SQL:

```json
{
  "schema": 1,
  "created": "fecha ISO",
  "settings": {"company_name": "BOBC Taller Artesanal"},
  "products": [], "recipes": [], "skus": [],
  "quotes": [], "invoices": [], "payments": [], "documents": [],
  "calculations": [], "inventory": [], "movements": [],
  "supplies": [], "supplyMovements": [], "packagingLinks": [],
  "expenses": [], "drafts": [], "auditLog": []
}
```

Los IDs actuales son strings/UUID según el origen. **No cambiar a `schema:2` de forma unilateral**; exige migración de cliente, API y SQL con pruebas y rollback. `normalizeState()` conserva las listas necesarias. La preservación de compatibilidad con antiguos datos BOBC Universal `schema:2` se maneja mediante restauración selectiva/copia, no borrado del estado original. Si se desarrolla nueva estructura, crear adaptadores y migración versionada.

---

## 4. Usuarios, perfiles, identidad y matriz de permisos

Administración exclusivamente dentro de BOBC, no desde la consola Supabase para el uso cotidiano. El administrador autoriza correo y perfil; el invitado activa cuenta con su propia contraseña y verifica el correo. RLS y RPC validan membresía activa; **ocultar botones no constituye autorización de seguridad**. No compartir cuentas ni contraseñas entre teléfonos.

| Acción | Administrador `admin` | Operadora `sales` | Producción `production` | Consulta `viewer` |
|---|:---:|:---:|:---:|:---:|
| Consultar datos comerciales y reportes | Sí | Sí | Según permisos de lectura | Sí |
| Crear/editar borrador de cotización | Sí | **No** | No | No |
| Emitir y anular cotización | Sí | **No** | No | No |
| Convertir cotización emitida a borrador de factura | Sí | **Sí** | No | No |
| Crear/editar borrador de factura y emitir | Sí | **Sí** | No | No |
| Modificar factura **ya emitida** | **No**, requiere anulación | **No** | No | No |
| Anular factura o cotización | Sí, con restricciones | **No** | No | No |
| Registrar iniciales, abonos y pago final | Sí | **Sí** | No | No |
| Confirmar entrega/envío de factura | Sí | **Sí** | No | No |
| Crear/editar recetas, fórmulas, productos | Sí | **Sí** | Sí | No |
| Ajustar producción e inventario | Sí | **Sí** | Sí | No |
| Crear y modificar gastos/configuración administrativa | Sí | Solo consulta | No | No |
| Crear usuarios, asignar perfiles, suspender | Sí | **No** | No | No |

**Regla de negocio explícita:** se puede modificar una factura mientras sea borrador. Al emitirla, su detalle —producto, cantidad, precio, descuentos/condiciones asentadas— debe quedar congelado para **todos**. Para corregir, el administrador anula con motivo y emite factura nueva; si hay pagos o entrega, se exige primero un procedimiento auditable de reversión/devolución, hoy **pendiente**. No permitir reescritura histórica silenciosa.

**Perfil concreto de operadora:** «Operador comercial y producción» (`profile_key='sales'`), autorizado a facturar, cobrar, entregar, producir y controlar inventario, **no** a crear cotizaciones ni anular. Este alcance es el **más reciente y prevalece** sobre versiones anteriores del datasheet que la limitaban a solo lectura comercial.

### Control de usuarios

- Tablas: `auth.users` (Supabase), `businesses`, `memberships`, `access_profiles`, `pending_invites`.
- Funciones: `bobc_claim_invitation`, `bobc_invite_user`, `bobc_update_user`, `bobc_revoke_invitation`, `bobc_is_member`, `bobc_is_admin`, y helpers comerciales de perfil.
- El primer administrador fue autorizado por proceso protegido; **no** permitir que cualquiera obtenga rol `admin` registrándose.
- Las invitaciones deben vincular **correo verificado** + `auth.uid()` + negocio; el alta de usuario en el panel de BOBC **no** genera ni revela contraseñas.
- Registro de cuenta, recuperación de contraseña y confirmación requieren configurar correctamente URL de callback. Se observó error previo de redirección a `localhost:3000` al confirmar el correo; **pendiente de corrección** en Supabase Authentication → URL Configuration y flujo de deep linking Android o página HTTPS de confirmación.

---

## 5. Flujo comercial obligatorio

### 5.1 Cotización

1. Desde una calculadora o desde Cotizaciones, preparar un **borrador editable** (líneas, cantidades, presentaciones, precios, envío, descuentos y notas).
2. «Guardar borrador» **NO** emite, ni asigna numeración de cotización definitiva.
3. El administrador revisa y pulsa explícitamente «Emitir cotización».
4. El documento queda inmutable. Se permiten anulación administrativa con motivo (sin borrar), o conversión a factura; no ambas cuando hay vínculo activo.
5. La operadora puede **consultar** la cotización existente y **convertirla a un borrador de factura**, sin modificar la cotización.

### 5.2 Factura

1. Puede crearse directamente o convertirse desde una cotización.
2. Siempre abrir **borrador editable antes de emitir**; cambios aquí no cambian la cotización histórica.
3. Emisión con confirmación inequívoca, número único, instantánea del documento (`snapshot`) y auditoría.
4. Después de emitir, **nadie** edita líneas, cantidades ni precios. Se distinguen estados del documento, pago y entrega.
5. Reintentar conversión de la misma cotización o confirmar repetidamente **no** debe crear facturas duplicadas.
6. Operadora puede facturar, no anular ni alterar documento emitido.

### 5.3 Cobros parciales y recibos

Factura total RD$3,500: inicial RD$1,000 + abono RD$1,200 + final RD$1,300 = **RD$3,500 recibido**, **RD$0 saldo** y **3 recibos**. Cada pago suma al ingreso **una sola vez**. Evitar negativos, montos superiores al saldo, pago a factura anulada y recibos duplicados. Diferenciar pago inicial, abono y pago final; varios pagos no implica un calendario contractual de cuotas salvo requisito adicional.

El dashboard debe distinguir *facturas parcialmente abonadas*, *pagadas en varios pagos*, *completamente saldadas*, *saldo pendiente* y *efectivo realmente cobrado por período*.

### 5.4 Entregas e inventario

- Estado de entrega independiente del estado de cobro; puede existir factura cobrada y pendiente de entrega, o entregada sin cobrar totalmente.
- Entrega confirmada: marcar entregada y descontar **productos terminados** exactamente una vez, con movimientos trazables.
- Botellas, stickers y demás empaques se descuentan **al registrar envasado/producción**, no otra vez en entrega.
- Si falta stock, impedir completar entrega; no permitir existencias negativas.
- Facturas anuladas sin entrega/pagos pueden anularse con motivo. Anulación con pagos o entrega se bloquea mientras no exista reversión/devolución auditada.

### 5.5 UX obligatorio

- Facturas en **filas de 1–2 líneas**, con número, fecha, total, saldo, estado y acciones compactas; tocar fila abre detalles.
- Filtros: Todas, Por cobrar, Con abonos, Varios pagos, Cobradas, Por entregar, Borradores, Anuladas.
- Si `saldo=0`, mostrar «Cobrado» **desactivado/no accionable**, nunca botón «Cobrar».
- Si `entregado=true`, mostrar «Entregado» desactivado/no accionable, nunca botón «Entregar».
- Cotizaciones y facturas con estado anulado deben mostrarlo de forma clara.
- Evitar botones de anular en interfaz de operadora, **y** denegarlo en API.
- Conservar opción de documento visual, impresión y compartir recibo/factura por WhatsApp.

---

## 6. Backend PostgreSQL: migraciones y contratos reales

### 6.1 Tablas relacionales creadas pero NO fuente principal de estado comercial

`businesses`, `memberships`, `access_profiles`, `pending_invites`, `products`, `recipes`, `skus`, `quote_drafts`, `quotes`, `invoice_drafts`, `invoices`, `invoice_lines`, `payments`, `deliveries`, `stock_movements`, `supplies`, `supply_movements`, `expenses`, `documents`, `audit_log`, `idempotency_operations`, `document_sequences`, `migration_batches`, `legacy_id_map`.

**En funcionamiento como fuente comercial Beta:** `bobc_shared_state` y `bobc_sync_events`. No insertar registros duplicados en las tablas normalizadas si aún no se puede garantizar la equivalencia transaccional con el snapshot; Codex debe planificar y probar migración progresiva.

### 6.2 RPC de sincronización

`bobc_sync_pull(p_business_id uuid)` → `{revision, state, updated_at?}`. Requiere membresía activa.

`bobc_sync_commit(p_business_id uuid, p_revision bigint, p_state jsonb, p_operation_id uuid)` → `{revision, duplicate?}`. Control de concurrencia e idempotencia (único `(business_id, operation_id)`), autorización por perfil, comparación de listas/historia y validaciones de integridad. SQL protegido con transacción/bloqueo por negocio.

**Invariantes actuales del servidor** (ver implementación antes de modificar): esquema `1`, arrays requeridos, límite de 6 MB aprox. en `pg_column_size`, no eliminar historia, no cambiar facturas emitidas excepto entrega o anulación administrativa permitida, no exceder total con cobros, una factura vigente por cotización, números no repetidos, stock no negativo. Las comprobaciones nuevas deben añadirse sin habilitar escrituras directas inseguras.

**Advertencia de arquitectura:** un *commit* en bloque valida/serializa todo el estado; es funcional para dos usuarios y pequeño volumen, pero tiene riesgo de conflicto si crece el negocio y limita granularidad, trazabilidad, rendimiento y modelado futuro. El camino objetivo debe ser RPCs por operación (`issue_quote`, `issue_invoice`, `record_payment`, `confirm_delivery`, `void_invoice`, `void_quote`, ajustes autorizados), con tablas relacionales como fuente de verdad, event log e idempotencia por comando. No migrar sin pruebas de equivalencia numérica.

### 6.3 Seguridad de datos y control de acceso

- Cada consulta filtra por `business_id` y usuario autenticado.
- RLS activa en tablas públicas; no abrir `SELECT/INSERT/UPDATE` a `anon`.
- Para funciones `SECURITY DEFINER`, proteger `search_path`, verificar `auth.uid()` y pertenencia/rol desde tablas, no desde banderas del cliente. Limitar `EXECUTE`; evaluar errores/avisos del Security Advisor.
- Tokens y contraseñas nunca en logs, documentos, pruebas, repositorio o respaldos comerciales exportados.
- El cliente almacena la sesión en `localStorage` y mantiene datos en IndexedDB: **no constituye cifrado local final**; asegurar sesiones en almacenamiento protegido y migración segura.
- Desactivar capturas solo cuando sea útil/aceptado por UX; no confundir con cifrado real.

---

## 7. Respaldos, recuperación, reinstalación y sesiones

**Sin registros históricos que importar al corte:** no es necesario obligar al usuario a exportar una base comercial inexistente. Pero ya hay snapshot remoto revisión 1; la app debe reconocerlo, no hacer otra inicialización inadvertida.

- Si hay datos locales previos, exportar JSON y conservar copia antes de migrar o desinstalar.
- Importar respaldos solo como administrador; fusionar por IDs con rechazo de discrepancias; evitar borrado/reemplazo de documentos históricos.
- Caché IndexedDB = copia local recuperable, no fuente de verdad. Si no hay internet: permitir lectura cacheada, **bloquear emisión/cobros/entregas/anulaciones/ajustes**. Mostrar «Sin conexión / Lectura» con mensajes claros, no falso «Sincronizado».
- Prevenir cargas dobles cuando el servidor responda tarde; idempotencia en backend y recuperación si el usuario reintenta tras timeout.
- Restauración completa debe contemplar contraseñas/credenciales aparte y validación de negocio/versión.
- **Firma Android:** el APK actual es debug y la clave puede cambiar entre compilaciones CI. Crear keystore de release privado **persistente** y resguardado; nunca subirlo a GitHub. Una firma distinta puede requerir desinstalar previo export/validación. No dar instrucciones de desinstalación sin confirmar el respaldo.
- Solucionar URL de confirmación/cambio de contraseña de Supabase: no `localhost:3000`. Preferir enlace HTTPS controlado por proyecto o deep link Android validado; la URI debe abrir la app o indicar con claridad volver a iniciar sesión.

---

## 8. Riesgos, deficiencias y tareas que Codex debe auditar

Clasificación honesta basada en código y documentación actual; algunos son controles por verificar, no vulnerabilidades explotadas.

| Prioridad | Hallazgo | Trabajo requerido |
|---|---|---|
| **P0** | No hay pruebas end-to-end verificadas en dos Android físicos | Probar login, roles, nuevo producto, factura, 3 abonos, entrega, anulación, sincronización y conflictos en 2 teléfonos con registros descartables |
| **P0** | Fuente de verdad comercial es snapshot global, no tablas relacionales | Auditar consistencia, operaciones atómicas, idempotencia y carrera entre comandos; definir migración normalizada sin perder funcionalidad |
| **P0** | Firma debug sin keystore persistente | Crear estrategia segura de firma/actualización antes de uso habitual; garantizar ruta de respaldo antes de migrar identidad de APK |
| **P0** | Confirmaciones Supabase redirigieron a `localhost:3000` | Corregir Auth URL Configuration y callback + prueba con correo nuevo, recuperación de cuenta y enlaces expirados |
| **P0** | Supabase devuelve advertencias `SECURITY DEFINER` expuestas | Auditar funciones privilegiadas, controles de rol, rutas RPC y búsqueda de abuso por operador/no miembro |
| **P1** | LocalStorage/IndexedDB sin capa de cifrado adicional comprobada | Diseñar acceso a sesión mediante Android Keystore, criptografía autenticada y respaldo cifrado restaurable |
| **P1** | No hay cola de comandos offline | Mantener bloqueo de escrituras sin red; documentar lectura offline y mensajes claros hasta diseño robusto |
| **P1** | Polling fijo cada 10s, snapshot entero | Evaluar Realtime por eventos + pull por revisión o sincronización incremental; manejo de backoff y batería |
| **P1** | Controles de bloqueo de documento y stock dependen también de comparaciones JSON | Pruebas de manipulación de payload y migración a RPC transaccionales por acción |
| **P1** | Cobros reembolsos/anulación con facturas ya cobradas o entregadas no está diseñado integralmente | Crear notas de ajuste / devolución y reversión auditada; no improvisar borrados |
| **P1** | Etiqueta/títulos aún mezclan 'Preview', 'Beta', 'LOCAL' en archivos legados | Consolidar etiquetas y advertencias según el estado real sin cambiar lógica |
| **P2** | Necesidad de manual para operador y restauración | Manual visual Android y plan de recuperación de dispositivo |
| **P2** | No existen pruebas QA de referencia visual en teléfonos estrechos | Capturas regresión UI, accesibilidad, listas y formularios |

**Nota de auditoría:** el datasheet previo `specs/BOBC_0.8_PERFIL_OPERADORA.md` fue redactado antes de introducir snapshot sync, y su sección «sin sincronización» ya es obsoleta; mantenerlo como archivo histórico, sin confundirlo con la situación actual. La referencia principal de estado es `specs/BOBC_0.8_SYNC_BETA_ESTADO.md` + código actual + este datasheet.

---

## 9. Hoja de ruta de ejecución para Codex (orden sugerido)

### Fase 0 — Congelar y auditar (obligatoria, no destructiva)

1. Crear rama derivada de `feature/bobc-0.8-private-sync` (o seguir trabajando dentro de ella con commits pequeños); conservar `main` y Universal.
2. Ejecutar `node --check` sobre JS, `node tests/test_logic.js`, `node tests/test_sync.js` y `gradle -p android-bobc-07 :app:assembleDebug`.
3. Inspeccionar versiones actuales, firmas, recursos Android, dependencias, RLS, functions y estado remoto **sin alterar datos**.
4. Documentar cobertura de QA faltante; registrar riesgos y establecer pruebas de regresión para fórmulas, precios, facturas y stock.
5. Confirmar el contrato actual `schema:1` y las rutas de recuperación.

**Entregable:** informe de diferencias código-datasheet, matriz de riesgos priorizada y proyecto compilable.

### Fase 1 — Correctitud de roles y transacciones

1. Expandir pruebas negativas para operador intentando anular factura, editar líneas emitidas, modificar cuentas, alterar cotización, suplantar `business_id`, enviar estados adulterados y reintentar pagos.
2. Probar atomicidad de tres abonos, stock después de entrega, IDs y números duplicados, anulación controlada y rechazo de estado obsoleto.
3. Revisar SQL de `bobc_sync_commit`: errores de conversión, datos inválidos, NULL, cantidades flotantes, tipos, referencias y modificación encubierta de campos.
4. Evitar autorización solo en botones: el backend decide.
5. Crear capa de commands/RPC dedicada si la auditoría detecta limitaciones del snapshot; preservar endpoints legacy durante transición.

**Entregable:** tests robustos y migraciones aditivas/reversibles, sin pérdida de información.

### Fase 2 — Auth y sesión seguros

1. Arreglar redirects Supabase de confirmación/recuperación con ruta que funcione en Android.
2. Comprobar activación de invitación, perfil, baja/suspensión y cambio de perfil en sesiones ya abiertas.
3. Proteger token/sesión y estado local; asegurar no exposición de credenciales ni acceso de web externa al bridge JS de Android.
4. Registro/auditoría de errores; no revelar claves en logcat ni toasts.

**Entregable:** acceso de los dos usuarios fiable, con test de cuenta nueva y revocación.

### Fase 3 — Sincronización de negocio lista para uso

1. Probar teléfono A → guardar producto/receta/inventario → teléfono B recibe lo mismo; repetir a la inversa.
2. Probar cotización administrador → conversión a factura operadora → abonos/entrega → dashboard de ambos.
3. Pruebas de carrera (simultáneo, red intermitente, pérdida de respuesta, reintento, reconexión, pantalla en segundo plano).
4. Optimizar polling, estados de conexión, manejo de errores y recuperación de conflictos.
5. Implementar backups automáticos protegidos y restore verificado.

**Entregable:** resultado de pruebas medible en dos Android reales; ninguno debe mostrar `Sincronizado` si no puede leer/confirmar el servidor.

### Fase 4 — Firma, distribución e instalación

1. Keystore permanente privado y configurado por secretos de GitHub Actions / entorno seguro.
2. Estabilizar `applicationId`, `versionCode`, política de upgrades y exportación ante cambio de firma.
3. Compilar release, verificar firma/hash, antivirus básico, `AndroidManifest.xml` y permissions.
4. Preparar APK de instalación privada (sin Google Play) y manual para ambos usuarios.

**Entregable:** APK firmada actualizable + procedimiento de recovery y despliegue.

### Fase 5 — Documentación y cierre

- Consolidar datasheet y manual de usuario; lista de pantallas, flujos, perfiles, arquitectura y datos.
- Incluir resultados reproducibles de CI/QA y limitaciones residuales.
- No etiquetar como versión final hasta completar criterios mínimos P0.

---

## 10. Matriz de aceptación y escenarios de prueba

| ID | Escenario | Resultado obligatorio |
|---|---|---|
| A01 | Administrador inicia en equipo A | Accede a negocio correcto, puede gestionar usuarios |
| A02 | Operadora activa invitación desde equipo B | Ve el mismo negocio, nunca el módulo Usuarios |
| A03 | Operadora manipula UI/REST para anular factura | El servidor rechaza el intento; estado no cambia |
| A04 | Operadora edita borrador de factura | Se guarda si tiene permiso y el estado es borrador |
| A05 | Operadora intenta modificar línea en factura emitida | Se rechaza; no cambia snapshot de factura |
| A06 | Administrador emite cotización | Emisión después de borrador y confirmación; número único |
| A07 | Operadora convierte cotización en factura | Abre borrador; factura emitida solo tras confirmación; mantiene vínculo |
| A08 | Dos clientes convierten la misma cotización | No se emiten dos facturas vigentes |
| A09 | Factura RD$3,500, abonos RD$1,000 + RD$1,200 + RD$1,300 | Saldo 0, tres recibos, ingreso RD$3,500 exactamente |
| A10 | Intento de abonar RD$1 adicional | Rechazado en servidor y UI marcada «Cobrado» |
| A11 | Entrega confirmada en equipo B | Descuenta terminado una sola vez; en A aparece «Entregado» |
| A12 | Repetir acción Entregar | Rechazado sin duplicar movimientos |
| A13 | Operadora crea/edita receta y añade inventario | Admin ve los cambios; no se alteran facturas previas |
| A14 | Administrador intenta anular factura cobrada/entregada | Bloqueo hasta implementar reversión/auditoría |
| A15 | Red desconectada | Lectura caché posible; no se confirman cobros, entregas ni emisiones |
| A16 | Dos dispositivos editan estado base de revisión idéntica | Uno confirma, el otro recibe conflicto y no pisa cambios |
| A17 | Reenvío de mismo `operation_id` | Un solo efecto, respuesta idempotente |
| A18 | Usuario suspendido conserva token antiguo | No puede leer/escribir datos del negocio (RLS/RPC) |
| A19 | Respaldo exportado e importado | Total de documentos y saldos se conservan, sin duplicados |
| A20 | Reinicio/reinstalación/actualización firmada | Recuperación controlada, login y datos remotos intactos |
| A21 | Primer alta / recuperación de contraseña | Confirmación válida en Android, no `localhost:3000` |
| A22 | Facturas en lista compacta móvil | Filas 1–2 líneas; acciones adaptadas a estado y rol |

Cada test necesita: **precondiciones, pasos reproducibles, resultado real, captura/log sin secretos, resultado PASS/FAIL y versión/commit**. Si algún punto es FAIL, no etiquetar release final.

---

## 11. Pautas estrictas de desarrollo

- Trabajar con **commits pequeños y descriptivos**, sin force push en ramas estables.
- No alterar el producto Universal ni sustituir su esquema de datos.
- No generar credenciales, correos de prueba reales ni datos ficticios directamente en la base comercial sin limpieza transaccional. Tests SQL deben usar `ROLLBACK` o entorno aislado.
- No romper la navegación Android, los documentos PNG, la impresión, la exportación JSON ni la lógica de costeo/rendimiento.
- No agregar tablas/columnas o permisos excesivos solo para «resolver errores»; RLS permanece activa.
- No sobrescribir registros históricos. Revisiones/actualizaciones deben ser trazables.
- Antes de cambiar firma o package Android, preparar respaldo y estrategia de instalación.
- En cada fase, actualizar documentación con `IMPLEMENTADO`, `VERIFICADO EN PRUEBAS`, `PENDIENTE` o `BLOQUEADO`; evitar promesas no respaldadas.
- No solicitar nuevas aprobaciones sobre decisiones técnicas triviales. Solo detenerse ante riesgo irreversible, falta de credenciales seguras o cambios de negocio que afecten datos reales.

---

## 12. Entregables pedidos a Codex

1. Informe de auditoría de código + esquema Supabase + seguridad, con evidencia.
2. Código actualizado en rama de BOBC 0.8, organizado y versionado.
3. Migraciones SQL versionadas, RLS documentada y pruebas automatizadas adicionales.
4. Instrumentación de sincronización, conflictos, errores y respaldo.
5. APK Android firmada de manera estable, si existe acceso seguro a keystore; de lo contrario, APK de QA debug claramente marcada.
6. Manual Android de instalación, activación y recuperación para administrador y operadora.
7. Datasheet actualizado, changelog y resultados de QA en dos dispositivos físicos antes de declarar final.

### Prompt de arranque sugerido

```text
Trabaja en el repositorio jcarlospm05/Sistema-Artesanal-Android, rama feature/bobc-0.8-private-sync. Lee primero specs/BOBC_0.8_3_HANDOFF_CODEX.md y contrasta con el código actual, migraciones de Supabase y CI. El producto es BOBC Taller Artesanal, NO Universal.

Continúa hasta entregar BOBC 0.8 con sincronización multiusuario segura, roles administrador/operadora, borradores editables, documentos emitidos inmutables, anulaciones solo del administrador, cobros parciales, entregas e inventario correctos. No modifiques main ni bobc-1.0-artesanal-universal. Ejecuta auditoría, tests y compilación por fases; corrige redirect de Auth, endurece backend y seguridad local, garantiza actualización APK firmada y documenta todo.

No pidas aprobaciones intermedias por decisiones técnicas ordinarias, pero no borres datos, cambies credenciales secretas ni hagas operaciones irreversibles sin salvaguardas. No declares que ya está listo si las pruebas con dos Android reales no se han realizado: distingue expresamente lo implementado de lo verificado.
```

**FIN DEL DATASHEET — BOBC 0.8.3 SYNC BETA / CODEX HANDOFF.**