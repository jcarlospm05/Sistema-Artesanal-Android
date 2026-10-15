# BOBC 0.8 — Perfil de operadora: facturación y producción

**Estado:** migración de permisos aplicada en Supabase y reglas de interfaz en rama de desarrollo. **No equivale a sincronización terminada.**

## Alcance confirmado por propietario
- Rol de la esposa: "Operador comercial y producción" (clave interna `sales` para conservar usuarios existentes).
- Puede **consultar** toda la información comercial: cotizaciones, facturas, abonos, entregas, productos, fórmulas, inventario, gastos y reportes.
- Puede **crear, guardar y emitir facturas**, editar sus borradores (incluidos los creados desde una cotización) y **convertir cotizaciones en facturas**.
- Puede registrar pagos iniciales, abonos, pagos finales, entregas y salidas del inventario asociadas a entregas.
- Puede crear/actualizar productos, fórmulas, recetas, materiales e inventario (registrando movimientos; sin borrar históricos).
- No puede crear/editar/anular cotizaciones, ni anular facturas, ni administrar usuarios o configuración privilegiada.
- No puede modificar conceptos, productos, cantidades ni precios de **facturas emitidas**. Ni el administrador debe cambiar silenciosamente documentos emitidos: requiere anulación documentada, seguida de otra factura.
- Si una factura tiene pagos o entrega, actualmente se **bloquea la anulación** hasta disponer de una reversión/devolución auditada. Esto también aplica al administrador.

## Permisos (resumen)
| Acción | admin | sales (esposa) | production | viewer |
|---|---|---|---|---|
| Ver documentos comerciales | Sí | Sí | según vista | Sí |
| Crear/editar cotización en borrador | Sí | No | No | No |
| Crear/editar/emitir factura desde borrador | Sí | Sí | No | No |
| Convertir cotización emitida a factura | Sí | Sí | No | No |
| Registrar abonos y entregas | Sí | Sí | No | No |
| Modificar recetas/productos e inventario | Sí | Sí | Sí | No |
| Anular facturas o cotizaciones | Sí, sujeto a reglas | No | No | No |
| Administrar usuarios | Sí | No | No | No |

## Implementación y límites
- Supabase: `access_profiles` actualizado; helpers de permiso `bobc_can_invoice` y `bobc_can_edit_production` con comprobación de pertenencia activa; RLS en borradores y escrituras de catálogo.
- La escritura remota de **facturas emitidas, cobros, entregas y movimientos de inventario** continúa cerrada deliberadamente hasta implementar las RPC transaccionales con idempotencia y auditoría.
- Preview Android: habilita operaciones locales solo para los perfiles correspondientes y oculta acciones no autorizadas; sigue mostrando "Sin sincronización" correctamente.
- La fuente de verdad de documentos comerciales multi-dispositivo y el historial de auditoría del servidor son la siguiente fase.
- BOBC 0.7.1 en `main` y BOBC Universal permanecen independientes.
