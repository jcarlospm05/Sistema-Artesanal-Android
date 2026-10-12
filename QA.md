# QA v0.3 PWA (2026-10-12)

Pruebas de navegador simulado, sin acceso de navegación HTTP a localhost por política del entorno:
- Registro producto / fórmula / presentación: aprobado.
- Cálculo A-G: 4000 ml + 700 ml = 4700 ml; 3x750 + 7x350 = 4700; costo 1244+700+410+250=2604: aprobado.
- Transferir a cotización y generar documento: aprobado.
- Registrar venta y cobro parcial; generar recibo: aprobado.
- Buscar documentos y guardar en estado de navegador: aprobado con implementación IndexedDB simulada.
- Prueba de uso offline con Service Worker real: pendiente sitio HTTPS.
- Prueba persistencia IndexedDB real en Android físico: pendiente.
- Prueba compartir PNG, impresión PDF y restaurar JSON en Android físico: pendiente.

Estado: **BETA, no aprobado para datos comerciales reales sin respaldo y pruebas de dispositivo**.
