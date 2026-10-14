# BOBC 0.7.1 · Android APK

Versión nativa empaquetada con Android WebViewAssetLoader, incluye todas las fuentes offline de la PWA BOBC 0.7.1. No requiere cuenta, Chrome ni Internet al usarla. Conserva la misma lógica de cocina/costos, catálogo, cotización/factura, cobro, entrega e IndexedDB de la PWA. *La base local Android es independiente de la base de Chrome*, por lo que hay que usar exportar JSON/importar JSON para llevar datos existentes.

- Package: `com.bobc.artesanal`
- Version: `0.7.1` (versionCode 71)
- Android: 8.0+ (`minSdk 26`), `targetSdk 33`
- Estado de firma: compilación debug firmada con clave de pruebas de GitHub Actions, destinada a instalación de prueba y no a Google Play.
- Respaldos exportados: Descargas/BOBC en Android 10+.
- Compartir recibos: acción nativa Android ACTION_SEND (imagen PNG).
- PDF/impresión: PrintManager de Android.
- Seguridad: contenido confiable empaquetado, se bloquean URLs externas dentro de WebView.

Para generar una APK de producción se necesitará un keystore de firma **persistente y privado**, control de versiones y pruebas reales en Android. Esta APK no usa ese keystore y no representa versión de producción.