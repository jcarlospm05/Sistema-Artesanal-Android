# Sistema Artesanal v6.0 — Proyecto Android móvil (fuente de desarrollo)

**Alcance de esta etapa: SOLO TELÉFONO ANDROID.** No se desarrolla PC ni sincronización central ahora.

## Qué contiene

- Proyecto Android Studio en Java, Android 14+ (`minSdk 34`, adecuado para Android 16).
- Base SQLite local, precargada y sin clientes reales (`app/src/main/assets/artesanal.sqlite`), 31 tablas, vistas y triggers.
- Interfaz 100% local HTML/CSS/JS dentro de Android WebView; no usa Python, Chrome externo, Internet ni PostgreSQL.
- Lógica comercial local en JavaScript con consultas SQL por un puente nativo Android. `SQLiteDatabase` ejecuta transacciones y verifica la integridad.
- Navegación para dashboard, recetas, producción, inventario, clientes, cotizaciones, facturas, cobros, empaques, documentos y configuración/logo.
- Archivo de respaldo SQLite mediante selector Android; exportación de JSON para lectura/intercambio, **pero la restauración automática se hace desde SQLite, no desde JSON**.
- Restauración de SQLite con confirmación, validación de integridad, claves foráneas y versión 6.x, con copia local previa.
- Facturas, cotizaciones y recibos como PNG, guardados en `Pictures/Sistema Artesanal/{Cotizaciones|Facturas|Recibos}`; uso de `ACTION_SEND` para compartir con WhatsApp u otras apps. Soporte experimental de impresión Android.

## ¿Cómo obtener un APK sin escribir código ni instalar Android Studio?

Puedes subir el contenido de esta carpeta a un **repositorio privado de GitHub** (la carpeta `.github` se debe subir también). En GitHub → Actions → "Construir APK Android de prueba" → Run workflow, descargar el artefacto `Sistema-Artesanal-Android-debug-APK` tras la compilación. Es un flujo de compilación **incluido pero aún no ejecutado**; puede necesitar ajustes según el entorno de compilación. El APK de depuración sería apto para pruebas, no publicación.

Alternativa: abrir esta carpeta como proyecto en Android Studio (JDK 17, SDK de Android 35 y Gradle 8.10.2), sincronizar Gradle y ejecutar *Build APK*. No es necesario escribir código en VS Code.

## Pruebas reproducibles sin compilar Android

Con Node.js 22 (experimental node:sqlite):

```
node --experimental-sqlite tests/test_android_repository.cjs
```

Este test evalúa reglas transaccionales reales contra una copia de SQLite. La prueba de navegación Chromium (`tests/test_mobile_ui.py`) se incluye pero el navegador de este entorno bloquea páginas locales, así que **no hay certificación visual ni test en Android real**. No se ha compilado un APK en esta sesión por ausencia de Android SDK y Gradle, y sin acceso a npm/Maven desde el contenedor.

## Restricciones importantes

- Uso experimental. **No introducir datos personales reales ni cobrar comercialmente antes de pruebas en Android físico y revisión de seguridad**.
- El archivo SQLite inicial y los respaldos aún no están cifrados, y no hay autenticación biométrica/PIN de la app. Protege el dispositivo y los archivos; para una versión comercial es prioritario agregar cifrado y bloqueo seguro.
- No hay sincronización con PC, ni multi-dispositivo. Android es la única fuente local de verdad.
- El sistema calcula costo de elaboración por lote, pero los costos estimados de una cotización no equivalen todavía a contabilidad exacta de costo de ventas FIFO por lote; se guarda la trazabilidad de las entregas.
- Las fechas de vencimiento para bebidas lácteas/alcohólicas requieren validación sanitaria independiente, y las facturas son comerciales, **no comprobantes fiscales DGII**.
- Actualmente el inventario es solo de productos terminados, no materias primas.

## Respaldos y restauración

1. Configuración → **Guardar base SQLite completa** → selecciona una carpeta de Drive/Archivos.
2. Para cambiar de celular, instala la misma app → Configuración → **Restaurar SQLite** → selecciona el respaldo guardado. Confirmará que se reemplazan los datos, manteniendo una copia local previa en caso de error.
3. Respaldar cada vez que registres pedidos importantes. Los archivos en Drive requieren acción manual.

## Estado

v6.0 **proyecto móvil de desarrollo**. Conserva la v5.6 de PC únicamente como antecedente histórico. El siguiente objetivo es compilar y probar en tu Android real, corregir lo hallado y luego aprobar una versión estable.