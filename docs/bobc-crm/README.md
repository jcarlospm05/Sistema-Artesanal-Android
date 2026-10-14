# BOBC CRM Web v0.3.1
Aplicación web convencional (NO PWA). Funciona desde el navegador del celular a través de GitHub Pages. HTML, CSS, JavaScript puro y JSON; sin TypeScript, sin manifest ni service worker. Carpeta independiente de BOBC Artesanía.

## Alcance
Núcleo IndexedDB con 51 entidades, referencias verificadas durante guardado, gestión inicial de prospectos/personas/empresas, búsqueda, conversión de prospecto a cliente y copias JSON.

## Limitaciones
Etapa inicial: las demás pantallas son marcadores de posición. No hay sincronización entre dispositivos. IndexedDB pertenece al navegador y origen; borrar datos del navegador puede borrar registros. Exportar JSON periódicamente. No usar datos sensibles de producción hasta completar seguridad y auditoría. Para carga desde GitHub Pages debe estar habilitado HTTPS y el repositorio publicar la rama donde reside esta carpeta. No se instala como PWA.
