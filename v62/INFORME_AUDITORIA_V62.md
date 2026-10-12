# Auditoría QA · Android v6.2

## Alcance
Código fuente heredado v6.1 más navegación móvil, presentación visual y calculadora de producción. Sin modificar el esquema SQLite v6.1 y sin registrar movimientos por cálculos.

## Resultados
- v6.0 lógica/SQLite: 18/18 pruebas aprobadas.
- v6.1 integridad: 18/18 pruebas aprobadas.
- v6.2 calculadora: 11/11 pruebas aprobadas.
- v6.2 persistencia en SQLite: configuración guardada, inválidos rechazados, `integrity_check=ok`.
- Chromium simulado: tres resoluciones (360/393/768), barra superior e inferior, menú hamburguesa, drawer, navegación, once módulos con submenús funcionales, calculadora modo B 3×750+7×350 ml = 4700 ml, transferencia a Producción y obligación de medir volumen antes de confirmar. Sin errores de JavaScript ni desbordamiento horizontal.
- Compilación APK: pendiente al redactar; registrar resultado real de GitHub Actions en el repositorio, no asumir éxito.
- Prueba física Android: pendiente; probar actualización desde v6.1, barras de sistema, teclado, compartir PNG, impresión y restauración ZIP.

## Casos matemáticos reproducidos
- Con fórmula patrón de 1175 ml por receta, 3×750 ml + 7×350 ml requieren 4700 ml, factor 4 y 700 ml de ron. Con presentación comercial de 700 ml se indica comprar una botella si no hay ron disponible.
- Modo ingredientes disponibles limita el volumen al ingrediente escaso, no permite combinaciones que superen producción.
- Con merma de 5%, aumenta volumen previo requerido.
- La lista de compras redondea hacia arriba, descuenta las existencias declaradas y usa precio por envase configurable.
- Rechazo de cantidades negativas, botellas fraccionarias o unidad de compra igual a cero.

## Riesgos que continúan abiertos
- La UI no sustituye ejecución/validación en dispositivo físico.
- No existen PIN/cifrado/autenticación interna ni sistema de identificación de usuarios; datos reales no recomendados.
- No control automático de inventarios de ingredientes: el usuario introduce existencias manualmente en calculadora.
- Los ingredientes por `unidad` pueden exigir redondeo o ajuste manual de recetas reales; compras son aproximadas y los precios configurados no son cotizaciones actuales de supermercados.
- La calibración comercial y la validación sanitaria se hacen fuera del aplicativo; no se debe usar la estimación como garantía de aptitud para venta.