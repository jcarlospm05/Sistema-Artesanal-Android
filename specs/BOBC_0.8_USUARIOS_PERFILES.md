# BOBC 0.8 — Usuarios y perfiles (implementación preliminar)

**Proyecto Supabase:** BOBC-PRIVATE (tsjbizuoxorebvccwmig)
**Rama:** feature/bobc-0.8-private-sync. **No cambia BOBC 0.7.1.**

## Qué se implementó
- RLS y datos de perfiles reales en Supabase: `admin`, `sales`, `production`, `viewer`.
- `memberships` con perfil, nombre y correo, más autorizaciones `pending_invites`.
- El correo del propietario está preautorizado como administrador **pendiente de verificación**. No se creó ninguna contraseña ni usuario Auth automáticamente.
- RPCs protegidas: `bobc_claim_invitation` (email confirmado y autorizado), `bobc_invite_user` (solo admin), `bobc_update_user` (solo admin) y `bobc_revoke_invitation` (solo admin). Auditan cambios.
- En la APK Preview: pantalla inicial de iniciar sesión/activar cuenta, y módulo **Usuarios y perfiles** para crear autorizaciones, cambiar perfiles, suspender/reactivar y cancelar invitaciones pendientes.
- No hay registro abierto de administradores. Un usuario sin invitación puede crear cuenta Auth pero **no puede acceder a BOBC**; Supabase RLS impide leer datos del negocio.

## Primer inicio del administrador
1. Instalar APK 0.8 Preview Usuarios **SIN desinstalar 0.7.1**.
2. En la primera pantalla, seleccionar **Tengo una invitación: activar cuenta** y registrarse con el correo administrador preautorizado; elegir contraseña única.
3. Abrir el correo de verificación de Supabase y confirmarlo. Si el enlace termina redirigiendo a una página ajena, basta con que el correo haya sido confirmado: volver a la APK.
4. Iniciar sesión con correo y contraseña. Al confirmar el correo, la RPC asigna el perfil administrador automáticamente, solo al correo preautorizado.
5. Abrir menú lateral > Usuarios y perfiles > Crear usuario. Introducir correo, nombre, perfil; guardar.
6. La persona autorizada instala BOBC y activa su cuenta desde la primera pantalla, con su propio correo y contraseña, verifica su correo y luego inicia sesión.

## Limitaciones y seguridad pendientes
- **NO ES LA VERSIÓN SINCRONIZADA FINAL.** Los registros de cotizaciones, facturas, pagos e inventario de esta Preview todavía son locales en cada teléfono. La autorización de usuarios sí utiliza Supabase.
- Control de acceso por rol en pantalla; las operaciones comerciales locales aún no tienen validaciones RPC multiusuario (fase pendiente). **No utilizar como sistema compartido de facturación real hasta que esté completado.**
- Sesiones en almacenamiento web interno: migrar a Android Keystore + almacenamiento cifrado antes de la entrega privada definitiva.
- Falta comprobar manualmente el correo de confirmación, recuperación de contraseña, UX Android real y el flujo dual con dos teléfonos.
- No se ha implementado cifrado final ni firma permanente APK. Una compilación debug en GitHub puede tener firma distinta; hacer respaldos antes de reinstalar/desinstalar.
- La alta en BOBC es autorización por email; Supabase Auth crea la cuenta cuando el usuario acepta y define su contraseña desde su teléfono.
- Los perfiles son inicialmente predeterminados, no personalizables: habrá perfiles editables más adelante si se aprueban.
- Los usuarios que no sean administradores pueden cerrar sesión desde el menú.