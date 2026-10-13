# BOBC — Artesanal Universal v1.0
Fecha: 13 de octubre de 2026 · Base: BOBC PWA v0.7

## 1. Alcance
Versión funcional de prueba para negocios artesanales heterogéneos: bebidas, alimentos, carteras y textiles, stickers e impresión, bisutería y fabricación a pedido. La misma PWA mantiene módulos de dashboard, cotizaciones, ventas, cobros, recibos y entrega de v0.7, y añade una ficha genérica de fabricación, materias primas y órdenes. No es el proyecto BOBC PostgreSQL de 37 módulos; sigue siendo una PWA local de usuario único con IndexedDB.

## 2. Cambios conceptuales
- Ponche → Producto / variante.
- Fórmula → Ficha de fabricación versionada (manufacturingSpecs).
- Ingrediente → Material por tanda, con unidad, costo consumido y empaques comerciales opcionales.
- Cocina A → A · Producción, con cálculo de tandas, merma y compras.
- Costos B → B · Costos, distinguiendo costo consumido del gasto de compra, empaque y mano de obra.
- Botellas → Presentaciones, expresadas en cualquier unidad de producción compatible.
- Los productos heredados de ponche se conservan; las recetas existentes se migran a fichas `batch` sin borrar ni alterar los históricos.

## 3. Métodos de fabricación soportados
| ID | Modelo | Ejemplo | Rendimiento |
|---|---|---|---|
| `batch` | Mezcla / receta | Ponche, jabón, velas, pastelería | 1 lote = x ml, g, kg o porciones |
| `unit` | Ensamblaje de unidades | Cartera, bisutería | 1 tanda = n piezas |
| `sheet` | Impresión por pliego | Sticker, serigrafía | 1 hoja/pliego = n unidades |
| `custom` | Fabricación por encargo | Artesanía personalizada | 1 trabajo = n piezas/metros/unidades |

No existe todavía un optimizador geométrico que distribuya formas físicas en pliegos ni un módulo completo de ruta de producción o planificación de recursos. El usuario introduce cuántas unidades se obtienen por pliego.

## 4. Estructura de datos nueva
La base física continúa siendo IndexedDB `bobc-pwa-local-v1`, almacén `documents`, clave `state`. El documento de estado cambia de `schema=1` a `schema=2`.

Colecciones preservadas: `settings`, `products`, `recipes`, `skus`, `quotes`, `invoices`, `payments`, `documents`, `calculations`, `inventory`, `movements`, `supplies`, `supplyMovements`, `packagingLinks`, `expenses`.

Colecciones nuevas:

**`manufacturingSpecs`**: `id`, `productId`, `legacyRecipeId?`, `version`, `title`, `method`, `outputQty`, `outputUnit`, `wastePercent`, `materials[]`, `operations[]`, `setupCostCents`, `created`.

**`manufacturingSpecs[].materials[]`**: `id`, `materialId?`, `name`, `quantity` por tanda, `unit`, `lineCostCents` consumido por tanda, `packQuantity` unidades por empaque comercial, `packPriceCents`.

**`manufacturingSpecs[].operations[]`**: `title`, `minutes` por tanda, `rateCentsPerHour`.

**`materials`**: `id`, `name`, `unit`, `packQuantity?`, `packPriceCents?`, `created`.

**`materialMovements`**: `id`, `materialId`, `type:entrada|salida`, `qty`, `reason`, `date`, `orderId?`.

**`productionOrders`**: `id`, `number`, `date`, `productId`, `specId`, `status:planned|completed`, `requests[]`, `result` congelado, `snapshot` de la ficha, `completedAt?`.

**`products`** añade `productionMethod`. **`skus`** añade `label`, `outputQty`, `outputUnit` sin eliminar `sizeMl` ni los identificadores usados en cotizaciones anteriores.

## 5. Unidades y conversiones
- Volumen: ml ↔ l (1 l = 1,000 ml).
- Masa: g ↔ kg (1 kg = 1,000 g).
- Longitud: cm ↔ m (1 m = 100 cm).
- Superficie: cm2 ↔ m2 (1 m2 = 10,000 cm2).
- Conteo: pieza/unidad/docena.
- Pliego y hoja; tiempo hora/minuto.
- Unidades de materiales no conversibles (lata, rollo, taza, sobre) se conservan cuando coinciden exactamente, sin inferir conversiones desconocidas.

No se aceptan conversiones entre dimensiones incompatibles (ej. mililitros y metros).

## 6. Cálculos canónicos
`volumen_o_cantidad_solicitada = suma(cantidad_de_presentacion × contenido_por_presentacion)` (previa conversión compatible).

`rendimiento_neto_estimado_por_tanda = rendimiento_nominal × (1 - merma/100)`.

`tandas = ceil(solicitado / rendimiento_neto_estimado_por_tanda)`.

`producción_nominal = tandas × rendimiento_nominal`.

`producción_útil = producción_nominal × (1-merma/100)`; en unidades discretas se trunca hacia abajo.

`excedente = producción_útil - solicitado`.

`material_necesario = cantidad_material_por_tanda × tandas`.

`paquetes_a_comprar = ceil(material_necesario / contenido_paquete)` cuando se define empaque comercial.

`costo_material_consumido = suma(costo_material_por_tanda × tandas)`.

`costo_compra = suma(paquetes_a_comprar × precio_paquete)` cuando existe, o costo consumido si no.

`mano_obra = suma(minutos_por_tanda/60 × tarifa_hora × tandas)`.

`costo_total = materiales_consumidos + mano_obra + preparación + empaques + otros gastos`.

`ingresos_previstos = suma(unidades × precio_venta)`; `ganancia_bruta = ingresos_previstos - costo_total`.

`margen_bruto_% = ganancia_bruta / ingresos_previstos × 100` cuando el ingreso es mayor que cero.

**Diferencia entre gasto de compra y costo consumido:** comprar un paquete comercial puede costar más o menos que la estimación inicial de consumo; la aplicación muestra ambos, no asume que son iguales.

## 7. Ciclos de vida
- Ficha → cálculo A → cálculo B → cotización (opcional) → factura → cobro y entrega independientes.
- Cálculo A/B no altera inventario por sí solo.
- Guardar orden crea estado `planned` sin afectar stock.
- Completar una orden exige material maestro vinculado y existencia suficiente por unidad convertible. Consume material y agrega unidades terminadas, con verificación de idempotencia.
- La entrega de factura consume unidades terminadas. Una factura pagada puede estar pendiente de entrega o viceversa.
- Los documentos emitidos continúan siendo privados/no fiscales (sin NCF o e-CF).

## 8. Migración reversible por respaldo
La aplicación transforma automáticamente `schema=1` a `schema=2` en el primer arranque. Conserva identificadores y datos antiguos de cotizaciones, facturas, pagos, documentos y registros de ponche. Agrega fichas de fabricación tipo mezcla a cada receta anterior. Una segunda migración sobre `schema=2` no duplica fichas. El programa mantiene una misma base IndexedDB: **exportar un respaldo JSON v0.7 antes de actualizar es muy recomendable**. Si se vuelve a ejecutar una v0.7 anterior, esa versión no podrá leer correctamente el esquema 2 sin restaurar un backup de esquema 1 en un entorno de prueba.

## 9. Limitaciones conscientes de v1.0
- La importación de ponches originales crea materias de ficha para cálculo; como los insumos antiguos no tenían `materialId` ni inventario, la finalización de una orden migrada exige vincularlos primero a materias primas nuevas. Se puede seguir haciendo presupuestos y cálculos mientras tanto.
- La edición de fichas genéricas y sus versiones posteriores está prevista para la siguiente iteración; esta versión registra nuevas fichas iniciales y permite ajustar consumos de una orden sin modificar la original.
- La entrada de producto terminado por orden cuenta únicamente presentaciones solicitadas. El excedente de producción se muestra en cálculo, pero no se añade como SKU separado al inventario.
- El navegador simulado utiliza un adaptador de IndexedDB solo para las pruebas automatizadas; la instalación/actualización en Android y el almacenamiento persistente real siguen pendientes de aceptación en dispositivo físico.
- Los envases/etiquetas del inventario `supplies` legado no son automáticamente los mismos que `materials`; no se mezclan saldos en un mismo movimiento.

## 10. Seguridad y distribución
GitHub Pages sobre HTTPS; Service Worker para archivos de app y funcionamiento sin conexión tras primera carga. Datos de cada dispositivo en IndexedDB, sin login ni sincronización entre celulares. Respaldos JSON exportables/importables. App privada de carácter no fiscal. El repositorio público contiene código, no datos IndexedDB locales.

## 11. Versiones, QA y fuentes
Base: BOBC PWA v0.7 con paleta pastel, menú lateral, dashboard y ventas.
Nueva: BOBC v1.0 Artesanal Universal.
Pruebas unitarias (`test_core.cjs`): migración, mezclas, stickers, carteras, unidades, costos, stock, idempotencia, entradas inválidas.
Prueba visual y funcional (`test_browser.py`): creación de sticker, cálculo A, costo B, cotización, entrada de material, orden, consumo/entrada de terminado, conversión a factura, cobro, recibo y entrega.
Repositorio: https://github.com/jcarlospm05/Sistema-Artesanal-Android
Rutas de publicación: /Sistema-Artesanal-Android/ y /Sistema-Artesanal-Android/bobc-movil/