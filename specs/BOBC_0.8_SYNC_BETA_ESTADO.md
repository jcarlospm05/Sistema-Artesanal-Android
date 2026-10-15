# BOBC 0.8.3 — Sync Beta · Estado técnico

Fecha: 2026-10-15. Rama: `feature/bobc-0.8-private-sync`.

## Implementado
- Supabase Auth: administrador y operador, con acceso privado y perfiles.
- PostgreSQL: tabla `bobc_shared_state` con documento BOBC compartido por negocio, control optimista de revisión, operaciones idempotentes, auditoría `bobc_sync_events` y funciones `bobc_sync_pull`/`bobc_sync_commit`.
- Reglas SQL: RLS de lectura por membresía, escritura exclusivamente mediante función transaccional, protección de facturas y cotizaciones emitidas, anulaciones exclusivas del administrador, rechazo de cobros excesivos, factura duplicada por cotización, número de factura/recibo repetido, saldo negativo de existencias.
- Cliente: pull al iniciar, poll cada 10s + al volver al primer plano, copia local IndexedDB, espera de confirmación del servidor antes de guardar, respaldo de migración y de conflictos, rechazo de operaciones sin conexión.
- Rol `sales`: puede facturar, convertir cotización, registrar pagos/entregas, y manejar producción e inventario. No anula ni edita documentos emitidos.
- Compilación separada `com.bobc.artesanal.sync08` para preservar BOBC 0.7.1 y Preview 0.8.1.

## Flujo de migración real
1. En el celular que ya usa BOBC, exportar copia JSON desde `Configuración y respaldos` de la aplicación antigua. **No desinstalar las anteriores.**
2. Instalar Sync Beta y acceder como administrador. Si el servidor no contiene datos, se inicializa una base común (con respaldo previo de la base local Sync Beta).
3. Desde Sync Beta, abrir Configuración y respaldos, importar JSON. La aplicación fusiona registros por ID y rechaza discrepancias en IDs existentes; solo el administrador puede hacerlo.
4. Revisar facturas, pagos, entregas y existencias tras la importación en administrador. Instalar misma Sync Beta en el segundo móvil, entrar como usuario autorizado y comprobar los mismos registros.
5. Los nuevos cambios se guardan en servidor o se rechazan. El estado local sirve como cache y recuperación.

## Límites, no ocultar
- BETA: faltan pruebas integradas reales en dos Android y con datos reales antes de llamarla final.
- Por seguridad, cobros, entregas y demás escrituras requieren internet; no hay cola transaccional offline.
- Conflictos se rechazan y se recupera el estado servidor; se guarda una copia del intento en IndexedDB para recuperación. No existe auto-merge silencioso concurrente.
- Base compartida funciona mediante snapshot JSONB y revisiones; las 24+ tablas relacionales normalizadas quedan preparadas, pero la aplicación todavía NO utiliza cada tabla separada. La migración relacional debe conservar el contrato de permisos y auditoría.
- No está implementado cifrado adicional completo de IndexedDB ni llave definitiva de firma Android; la APK es compilación de prueba, NO versión de seguridad endurecida final.
- Corregir URL de confirmación Supabase que redirige a `localhost:3000` para nuevas cuentas: Authentication → URL Configuration. Usuarios existentes confirmados pueden iniciar sesión.
- No conservar contraseñas de Supabase en el repositorio ni incluir llave `service_role` en cliente.

## QA
- Tests JavaScript de lógica de pagos, anulaciones, rendering y sincronización de dos clientes.
- SQL simulado con transacciones `ROLLBACK` contra proyecto BOBC-PRIVATE: inicio vacío, emisión de cotización, conversión a factura, registro de pago y lectura de revisión: **3**. Sin insertar facturas reales.