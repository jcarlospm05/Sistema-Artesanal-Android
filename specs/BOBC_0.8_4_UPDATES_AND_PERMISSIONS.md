# BOBC 0.8.4 — Permisos y actualizaciones (rama de desarrollo)
Fecha: 2026-10-15.

## Cambios preparados (no desplegados)
- Rol `sales`: permite crear/emitir cotizaciones, además de facturación, producción, cobros y entregas. Sigue sin administrar usuarios ni anular documentos.
- Nueva migración `20261015123000_bobc_sales_full_operations.sql`: habilita cotizaciones y gastos operativos; mantiene la inmovilidad de documentos emitidos y las anulaciones solo para `admin`.
- `bobc08_updates.js`: consulta la versión estable más reciente en GitHub Releases y muestra aviso y enlace al APK si existe un asset .apk en una versión posterior a 0.8.3. Sin actualizaciones silenciosas.

## IMPORTANTE: para actualizar APK sin desinstalar
1. La APK nueva debe tener el mismo `applicationId` (`com.bobc.artesanal.sync08`) y un `versionCode` más alto (por ejemplo 84). Actualmente el proyecto aún tiene versionCode 83.
2. Todas las APK instaladas/actualizadas deben firmarse con **la misma clave**. Las firmas debug efímeras de CI pueden cambiar: no garantizan actualización in situ. Configurar firma de release persistente (secretos fuera del repositorio).
3. Publicar una release estable semántica `v0.8.4` con APK firmado como asset. El aviso enlaza al instalador de Android que requiere consentimiento. **No garantiza instalar automáticamente**.
4. Realizar respaldo JSON y ensayo de actualización sobre dos teléfonos. **No desinstalar** aplicaciones con datos sin verificar recuperación.
5. La versión 0.8.3 instalada no contiene todavía el detector y no puede ver la nueva ventana hasta recibir una actualización compatible.

## Futuro: actualización web sin APK
La WebView actual carga código HTML/JS desde `app/src/main/assets/www` empacado dentro del APK. Cambiar GitHub no cambia esos archivos instalados. Una actualización de contenido web sin APK requiere una arquitectura nueva de contenido remoto firmado, hashes y validación, despliegue controlado, recuperación offline y pruebas de seguridad. **No se ha implementado**.

## Validación pendiente
- Aplicar migración al proyecto BOBC-PRIVATE tras copia y auditoría (esta rama por sí sola no cambia Supabase).
- Alinear todos los controles de UI de creación de cotizaciones y gastos.
- Pruebas SQL de permisos sales versus admin y prohibición de alteración de factura/cotización emitida.
- Pruebas APK compilación y flujo de update en Android 8+ con clave persistente.
- Verificar GitHub Releases, checksum y firma. No publicar la versión como producción antes de superar QA.
