# Sistema Artesanal — Android v6.1 (correctiva / QA)

**SOLO Android**. La versión v6.0 queda archivada, y los módulos de computadora y sincronización no se incluyen en esta etapa.

## Qué cambió

- SQLite local (31 tablas heredadas + nueva tabla `document_snapshots`, protecciones de inmutabilidad y campo de finalización de factura); validación de importes, 10 dígitos telefónicos, fórmulas y existencias.
- Migración automática y transaccional de bases v6.0 a v6.1 al abrir la app. No se sustituye una base existente por la semilla.
- Bloqueo SQL de modificaciones destructivas a facturas, cobros, movimientos y producción consolidados. La emisión de factura exige al menos una línea y total positivo. Se impide una segunda entrada por producción.
- Cliente, teléfono, marca y logo se congelan al emitir cotización, factura y recibo; cambios posteriores no reescriben esos documentos.
- Empaques: coste por botella, por pack o por pedido; costes por lote NO se recargan en venta (requieren imputación en producción).
- Rechazo de ingredientes ajenos a la versión de receta; recetas que contienen leche/huevo deben registrar refrigeración para generar lotes disponibles. Esto **no** certifica seguridad alimentaria, cocción ni vida útil.
- `WebChromeClient` para diálogos de confirmación, prompts y selección de logo en Android; pantalla inicial tolera almacenamiento temporal del navegador deshabilitado.
- Respaldo completo ZIP desde Android: copia SQLite consistente + PNG internos guardados por la app + manifiesto y SHA-256. Restauración ZIP y SQLite antigua con validación y copia previa. JSON se exporta para inspección, **no se importa** en esta versión.
- APK QA compilado por GitHub Actions, no firmado para distribución comercial.

## Obtener APK desde GitHub

Repositorio privado: `https://github.com/jcarlospm05/Sistema-Artesanal-Android`.
Acciones → **Android v6.1 - compilar y auditar** → abrir la ejecución verde más reciente → Artifacts → `Sistema-Artesanal-Android-v6-1-QA-APK` → descomprimir → `app-debug.apk`.

**Firma e instalaciones existentes:** v6.0 y v6.1 pueden estar firmadas por claves debug DISTINTAS. Antes de desinstalar v6.0, ir a Configuración y **exportar un SQLite**, guardarlo fuera del teléfono, comprobar el archivo y luego desinstalar v6.0 / instalar v6.1 / restaurar el SQLite desde la configuración. Esta migración entre APK aún requiere validación en un dispositivo físico; NO desinstales una app con datos importantes sin copia verificada. Las compilaciones QA v6.1 intentan reutilizar la misma firma de prueba mediante caché GitHub Actions, pero no hay firma de lanzamiento final.

## Respaldo de los documentos

En v6.1 los PNG guardados/compartidos se conservan tanto en Galería (`Pictures/Sistema Artesanal/`) como en la carpeta privada de la aplicación para incluirlos en el backup ZIP. **Las imágenes creadas por v6.0 en Galería antes de actualizar NO se recuperan automáticamente en el backup de v6.1**; cópialas aparte antes de migrar. Los PNG que no se han generado pueden regenerarse desde los datos históricos y la plantilla versionada, siempre que existan las instantáneas pertinentes.

## Pruebas y advertencias

- SQLite original: 18/18 pruebas aprobadas.
- Regresión v6.1: 18/18 aprobadas (defectos C01-C04, C06-C10, anti duplicados, migración, etc.).
- Interfaz en Chromium simulado: 30/30 módulos × resoluciones aprobados, más vista de documento. **No es un ensayo de WebView en Android**.
- Compilación APK: ver comprobación más reciente en GitHub y anexo de auditoría. Pruebas físicas Android siguen pendientes.
- El respaldo y la restauración ZIP nativos, compartir WhatsApp, selectores, impresión y persistencia tras reiniciar deben verificarse en Android real antes de uso comercial.
- SIN cifrado/PIN interno o autenticación dedicada de app. No se recomienda usar con clientes, facturas y cobros reales antes de corregir estas medidas y finalizar prueba física.
- No es factura fiscal DGII ni certificación de producción sanitaria. No promete vida útil de bebidas.

## Para desarrollo y auditoría

La base v6.0 permanece en el archivo fuente anterior. `app/src/main/assets/migration_v61.sql` contiene las sentencias de actualización, que se aplican al iniciar una instalación anterior desde `DatabaseBridge` en una transacción. En la fuente completa de este ZIP, la base semilla ya está migrada a la versión 61.

Pruebas en entorno Node con SQLite:

```bash
node tests/test_android_repository.cjs
node tests/test_v61_regression.cjs
```

Ver `docs/INFORME_AUDITORIA_v61.md` y `docs/TEST_RENDER_v61.json` para evidencia y pendientes.