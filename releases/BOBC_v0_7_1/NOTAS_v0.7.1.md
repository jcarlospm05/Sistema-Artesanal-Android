# BOBC v0.7.1 — Recuperación compatible tras v1.0 Universal

## Corrección

La actualización BOBC v1.0 convirtió el estado IndexedDB de `schema:1` a `schema:2` bajo la clave `state` en la base `bobc-pwa-local-v1`. El código anterior de BOBC v0.7 rechazaba cualquier esquema distinto de 1 y mostraba que la base era inválida.

BOBC v0.7.1 detecta `schema:2`, genera una copia independiente compatible con 0.7 y la almacena en la clave `state-v07-restaurada`. **La clave original `state` y su estructura Universal no se modifican.**

Los productos con receta tradicional y envases por ml, sus cotizaciones/facturas compatibles, recibos y movimientos relacionados son conservados en la copia. Los registros exclusivos de artesanías universales no se muestran en v0.7, pero permanecen intactos en la base original para la rama v1.0.

Cuando la base original sigue en schema 1, BOBC mantiene el mismo funcionamiento y almacenamiento previo. La creación de copia ocurre solamente ante schema 2. Cuando la copia ya existe, se reutiliza sin regenerar.

## Validación

- Syntax check app.js: OK.
- 5/5 pruebas unitarias Node VM: OK (conversión, preservación, aislamiento, caso sin ponche y reinicio separado).
- Navegador móvil real: pendiente de prueba del usuario. La política del navegador automatizado de este entorno bloquea las URL locales y de prueba; no se ha presentado como validada su ejecución en el dispositivo.

## Actualización de caché

`bobc-pwa-v0-7-1` y `bobc-movil-v0-7-1`.

## Ruta

`https://jcarlospm05.github.io/Sistema-Artesanal-Android/bobc-movil/`