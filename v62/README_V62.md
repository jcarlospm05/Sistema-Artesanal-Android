# Sistema Artesanal Android v6.2 — UX y Calculadora

**Tipo:** actualización QA sobre Android v6.1 (misma base SQLite local, versión interna de esquema 61).

## Navegación móvil
- Barra superior de app con botón hamburguesa, marca y acceso a calculadora.
- Menú lateral tipo drawer con apertura/cierre y submenús por módulo; fondo oscurecido fuera del menú.
- Botones rápidos del dashboard para ocho módulos.
- Barra inferior fija con cinco acciones: Inicio, Calculadora, Producir, Cotizar, Cobrar.
- Paleta lila/morado/negro en toda la interfaz y documentos.
- Contenedores nativos Android con `WindowInsets` de status bar, recorte de cámara, navigation bar y teclado. Las franjas de reloj/batería y gestos/botones Android se respetan.
- Icono nuevo de lanzador. `versionCode` 62, `versionName` 6.2.0-qa.

## Calculadora en dos modos
1. **Tengo ingredientes:** elige producto, versión de receta, cantidades existentes y merma estimada. Calcula los mililitros que alcanzan, ingrediente limitante, máximo de botellas por tamaño individual y mezcla de presentaciones.
2. **Necesito botellas:** elige combinación (p. ej. 3×750 + 7×350 ml), existencias previas por ingrediente, presentación comercial de compra (p. ej. ron de 700 ml) y precio por paquete. Calcula litros, ingredientes proporcionales, unidades enteras de compra, presupuesto de ingredientes y envases.
3. **Guardar configuración:** almacena los parámetros por versión de fórmula en la base SQLite. No modifica inventario.
4. **Enviar a producción:** transfiere el plan al formulario del lote. **Exige medir el volumen real** antes de registrar producción.

## Verificaciones
- Pruebas previas de SQLite: 18/18.
- Pruebas correctivas v6.1: 18/18.
- Nuevas pruebas de la calculadora: 11/11.
- Prueba de persistencia de parámetros en SQLite: aprobada.
- Pruebas de UI en Chromium de escritorio simulando móvil 360, 393 y 768 px: menú, barra inferior, submenús, cálculo, transferencia, accesos rápidos, sin desbordamiento, sin excepciones JavaScript; **no equivale a emulador/instalación física Android**.

## Instalación
APK QA compilado en GitHub Actions `Android v6.2 - calculadora y UX` para `jcarlospm05/Sistema-Artesanal-Android`. Reutiliza firma debug QA v6.1 por caché, pero si Android detecta firma distinta **no desinstalar v6.1 antes de exportar el respaldo ZIP con datos e imágenes**.

## Precauciones
- Sin protección PIN/cifrado de base; no datos personales reales todavía.
- Cálculos **teóricos**, definidos por fórmulas del usuario. No garantizan volumen real, exactitud de compras, precios de mercado, rendimiento sanitario ni vida útil.
- Los insumos pueden tener variación de densidad y disponibilidad; la calculadora usa unidades de receta (ml, g, unidad), sin conversiones automáticas entre unidades.
- No incorpora módulo PC ni sincronización servidor.