# BOBC 0.8 — Entrega parcial: funciones comerciales locales

**Estado: PREVIEW EXPERIMENTAL; NO ES LA VERSIÓN SINCRONIZADA FINAL.**

La versión 0.7.1 instalada se mantiene inalterada: esta preview usa `applicationId` independiente
`com.bobc.artesanal.preview08` y se instala junto a ella. Los datos locales NO se copian
solos entre instalaciones; antes de desinstalar cualquier versión exportar respaldo JSON.

## Cambios implementados y comprobables

- Cotizaciones desde Costeo a **formulario de edición**, sin emisión automática.
- Facturas desde cotización a **formulario de edición**, sin emisión automática.
- Guardar/editar borradores sin número comercial; solo `Emitir` tras confirmación lo asigna.
- Anulación de cotizaciones/facturas con motivo e historial `auditLog`; no se eliminan números/documentos.
- Impedir anular factura que tiene abonos o entrega, e impedir anular cotización ya convertida.
- Impedir pago de facturas anuladas, pagos superiores al saldo y segunda emisión de una cotización.
- Listas compactas con filtros: abiertas, con abonos, múltiples pagos, cobradas, entregas, anuladas y borradores.
- Etiquetas `Cobrado` y `Entregado` que no ejecutan acciones nuevas.
- Etiquetas de navegación **provisionales**: Planificación de Elaboración / Costeo y Rentabilidad.
- Estadísticas vigentes excluyen las facturas anuladas.
- Mantener fórmulas de cocina, costeos, entrega y recibos previos.
- `android:allowBackup=false`, WebView local offline sin permiso INTERNET.

## NO IMPLEMENTADO todavía

- La **sincronización** entre celulares; falta conectar Supabase/Auth/RLS y ejecutar migraciones.
- Inicio de sesión administrador / operador y autorización real en servidor.
- Cifrado del almacenamiento local, PIN/huella, exportación cifrada, clave permanente de firma APK.
- Reversos de pagos, devoluciones, anulación de factura ya pagada/entregada.
- Migración automática de datos de 0.7.1 a la preview; usar Exportar/Restaurar JSON y verificar.
- Pruebas instrumentadas en dispositivos Android reales y de doble concurrencia.

**No subir datos reales de clientes a esta preview hasta activar cifrado/roles/sincronización y completar auditoría.**

## QA

`node tests/test_logic.js` revisa estados, saldo, doble pago, anulaciones y HTML compacto. La
compilación CI comprueba sintaxis JS y ensamblado Gradle. El navegador automatizado en este entorno
bloquea URLs locales, así que la interacción táctil y el flujo completo en Android siguen pendientes.

## Próximo paso Codex

Ver `specs/BOBC_0.8_DATASHEET_CODEX.md` para contratos backend. Implementar RLS y RPC transaccionales,
configurar los dos usuarios, pruebas de migración, encriptación y firma permanente, sin tocar `main`.