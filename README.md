# BOBC PWA · Taller Artesanal v0.3 (beta)

Instalación de prueba Android usando GitHub Pages. App estática y sin servidor.

## Funcionalidad disponible
- Calculadora A–G con costos, margen, por SKU, volúmenes, gastos extra, y transferencia al POS.
- Catálogo de productos / fórmula inicial / 2 presentaciones por creación.
- Cotización y venta directa, sin seleccionar cliente; convertir cotización a venta.
- Cobro parcial o total, comprobantes y visor de documentos; PNG, compartir y PDF con impresión del navegador.
- Inventario manual, salida al confirmar entrega; control contra stock negativo.
- Datos privados en **IndexedDB del navegador Android**. No es SQLite y no se sincroniza entre dispositivos.
- Respaldo completo exportable e importable mediante JSON.
- Service Worker para abrirse sin conexión después de la primera carga exitosa.

## Limitaciones de esta beta
- No es una sustitución integral de BOBC Android v0.2: órdenes de producción, lotes físicos detallados, packs complejos y versionado de fórmulas están pendientes de migración a PWA.
- No genera NCF, e-CF ni documentos fiscales; las ventas se rotulan como no fiscales.
- IndexedDB depende de Chrome y del almacenamiento de sitio: borrar datos del sitio, cambiar de navegador, o desinstalar puede eliminar la base. Exportar respaldos frecuentemente.
- Datos sin cifrado de extremo a extremo en dispositivo; no almacenar información sensible.
- Pruebas automatizadas realizadas en Chromium con IndexedDB simulado. Falta prueba funcional física Android con persistencia real / impresión / WhatsApp.

## Publicar como GitHub Pages
Ruta de contenido: `docs/` en rama principal. En GitHub: Settings > Pages > Build and deployment > Deploy from a branch > `main` > `/docs` > Save. Si el repositorio privado no permite Pages con el plan actual, convertirlo a público o elegir repositorio público dedicado; no publicar documentos confidenciales.

La dirección, una vez habilitada, normalmente será `https://jcarlospm05.github.io/Sistema-Artesanal-Android/`. **Comprobar la URL antes de comunicar que está publicada.**

## Instalar en Android
Chrome > abrir URL HTTPS de GitHub Pages > menú ⋮ > Instalar aplicación / Añadir a pantalla de inicio. Abrir por primera vez con conexión, y después probar en modo avión.
