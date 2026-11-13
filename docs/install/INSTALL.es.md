<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Instalación de 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · **Español** · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Si hay alguna diferencia con la versión en inglés, prevalece la versión en inglés.*

Aquí están los detalles detrás de la versión breve del [README](../readme/README.es.md): requisitos del sistema, la advertencia de SmartScreen, Control Inteligente de Aplicaciones y cómo comprobar una descarga, los tres paquetes, el menú contextual de Windows 11, las asociaciones de archivos y la desinstalación.

## Requisitos del sistema

**Windows 7 o Windows Server 2008 R2, x64 o x86. En arm64, Windows 10.**
No hace falta nada más: el runtime de C está enlazado de forma estática (`-MT`), así que los binarios no importan más que las DLL del propio Windows: ni redistribuibles ni .NET.

Ese requisito mínimo se *deduce* de lo que exigen los paquetes, y se ha probado en Windows 7 SP1 con las actualizaciones posteriores instaladas (PowerShell 5.1 entre ellas), en Windows 10 22H2 y en Windows 11, todos de 64 bits. En Windows 7 y 10 la prueba abarcó la instalación y la desinstalación del `.msi` x64 para todos los usuarios y por usuario, el asistente de instalación, el `.zip` x64, todos los códecs añadidos y todos los formatos tar de un solo paso, el menú contextual, las asociaciones de archivos y el archivo de ayuda, además del `.msi` y el `.zip` x86 ejecutándose en Windows de 64 bits. No se ha probado nada más en Windows: ni Windows 8 u 8.1, ni Windows Server, ni Windows de 32 bits, ni hardware arm64, ni Windows 7 sin esas actualizaciones. El requisito mínimo es además más alto que el del 7-Zip original (upstream), cuyos binarios todavía se cargan en Windows XP. Tres cosas lo sitúan ahí, y la segunda es la que ningún ajuste de compilación puede deshacer:

- El `.msi` declara `InstallerVersion="500"`, y Windows Installer 5.0 se distribuyó "with Windows Server 2008 R2 and later and Windows 7 and later" (es decir, con Windows Server 2008 R2 y posteriores y con Windows 7 y posteriores) ([Microsoft][msi-versions]). El `.zip` portátil no pasa por Windows Installer, pero véanse los dos puntos siguientes.
- **zstd y fast-lzma2 usan una sincronización que solo existe desde Vista.** Ambos fuerzan `_WIN32_WINNT 0x0600` en sus propios encabezados y llaman directamente a `InitializeConditionVariable` / `SleepConditionVariableCS`, así que `7z.dll` y `7za.exe`, los dos binarios con los códecs compilados dentro, importan cuatro funciones que Windows XP y Server 2003 no tienen. El `7z.dll` de upstream no importa ninguna.
- La cadena de herramientas: se compilan con Visual Studio 2022, cuya lista de destinos admitidos es Windows 7 y posteriores; Vista y Server 2008 figuran como "No" ([Microsoft][vs-targeting]). La versión del subsistema enlazada es 6.0 en x64 y x86 y 6.2 en arm64, y Windows en arm64 empieza en Windows 10 de todos modos.

Windows Vista y Server 2008 quedan a medio camino: los binarios se cargarían, pero la cadena de herramientas no los admite, el instalador no se ejecutará en ellos y 7-ZSTar no se ha probado en ellos.

**Linux se admite solo como compilación de línea de comandos; macOS no se admite.**
El fork compila un `7zz` nativo (el programa de consola `Alone2`) con gcc mediante su propio makefile, que incluye los de upstream sin modificar ninguno:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Solo se ha compilado y probado en Ubuntu 24.04 con gcc 13.3 (x86-64): la compilación no genera advertencias con las opciones de upstream, la prueba de humo de 77 comprobaciones se supera, y los 25 vectores de interoperabilidad creados en Windows y los 37 creados en Linux dan los mismos veredictos que en Windows. Los dos archivos propios del fork que tocó el port se siguen compilando sin cambios en Windows (compilación x64 limpia; las pruebas de humo y la relectura de interoperabilidad se superan). No hay interfaz gráfica. Los demás destinos de Linux de upstream (`7za`, `7zr`, `7z.so`) no se admiten: a sus listas de objetos de gcc les falta lo que necesitan los cambios del fork en los manejadores de upstream, así que se espera que fallen al enlazar. No se han verificado otras arquitecturas, distribuciones ni compiladores, y macOS nunca se ha compilado, por lo que no se puede indicar ningún `MACOSX_DEPLOYMENT_TARGET`. Los pasos de compilación, las pruebas y los límites conocidos están en `build/linux/README.md`; la interoperabilidad con las herramientas de Linux, en `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Paquetes sin firmar, SmartScreen y Control Inteligente de Aplicaciones

**Los instaladores y programas de una versión de 7-ZSTar no están firmados con código por una autoridad de certificación**, y este proyecto no tiene ningún certificado de firma de código. Por eso Windows no puede saber quién publicó el archivo, y cuando ejecutas el `.msi`, o un programa del `.zip`, por primera vez, SmartScreen de Microsoft Defender (Microsoft Defender SmartScreen) puede detenerlo con una advertencia. La documentación para desarrolladores de Microsoft incluye "No signature" (sin firma) entre los casos que muestran una advertencia titulada «Windows protegió su PC» ("Windows protected your PC" en el texto de Microsoft), en la que el usuario tiene que elegir "Run anyway" ("Ejecutar de todas formas") antes de que se ejecute la aplicación ([Microsoft][smartscreen-rep]). La directiva de empresa puede eliminar esa opción por completo; en un equipo así, consulta a quien lo administra.

Lo único de una versión que *sí* está firmado es el pequeño paquete que coloca 7-ZSTar en el primer nivel del menú contextual de Windows 11, dentro del `.msi` para todos los usuarios. Su certificado es autofirmado y se genera al compilar ese único paquete, así que no es la firma de una autoridad de certificación y no dice nada sobre quién compiló el paquete; consulta [el menú contextual de Windows 11](#el-menú-contextual-de-windows-11) para saber qué hace y cómo rechazarlo.

La advertencia no demuestra que un archivo sea malo, y su ausencia no demostraría que un archivo sea bueno. Lo que sí puedes comprobar tú mismo es que tu copia es exactamente la publicada en la página de la versión. Cada versión incluye un archivo llamado `SHA256SUMS`: una línea por paquete, con un hash SHA-256 seguido del nombre del archivo.

1. Descarga el paquete y `SHA256SUMS` de la misma página de la versión, en la misma carpeta.
2. Abre PowerShell en esa carpeta y compara. Sustituye el nombre por el del archivo que descargaste:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` significa que los hashes son idénticos. Si prefieres verlos tú mismo, ejecuta
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` y busca el mismo
   nombre de archivo en `SHA256SUMS`; la comparación no distingue entre mayúsculas y minúsculas.
3. Si obtienes `False`, o el nombre del archivo no está en `SHA256SUMS`, no lo ejecutes: elimina el archivo y vuelve a descargarlo. Si sigue sin coincidir, infórmalo como se describe en [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` solo cubre los archivos subidos a esa versión. Si compilas tú mismo la misma etiqueta (tag), obtendrás hashes distintos (el paquete del menú contextual se firma con un certificado nuevo en cada compilación), y el código fuente se publica con cada versión por si prefieres compilarlo: consulta [build/README.md](../../build/README.md).

Cuando los hashes coincidan y estés conforme con el origen del archivo:

- **`.msi`**: ejecútalo como de costumbre. Si SmartScreen lo detiene, elige la opción para ejecutarlo de todas formas ("Run anyway" en un Windows en inglés, "Ejecutar de todas formas" en un Windows en español). Puede que primero haya que desplegar la ventana de advertencia: en el equipo con Windows 10 que se probó, solo ofrecía un botón para no ejecutar el archivo hasta que se hacía clic en el vínculo bajo su mensaje. Después, el `.msi` para todos los usuarios pide la aprobación de un administrador como cualquier otro instalador.
- **`.zip`**: extráelo y ejecuta `7zFM.exe` o `7z.exe` desde la carpeta. Los programas que contiene tampoco están firmados, así que Windows puede mostrar la misma advertencia la primera vez que ejecutes cada uno.

SmartScreen advierte según lo conocido que sea un archivo, no solo según las firmas; un archivo que ha descargado poca gente puede activarlo incluso estando firmado. Nada de lo descrito aquí cambia eso, y ninguno de los pasos anteriores desactiva SmartScreen.

### Control Inteligente de Aplicaciones en Windows 11

Algunos equipos con Windows 11 tienen activada una protección más estricta llamada **Control Inteligente de Aplicaciones**. Cuando está activada, Windows bloquea los archivos sin firmar a menos que el servicio en la nube de Microsoft pueda avalarlos, y una versión nueva normalmente no tiene ese registro ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). A diferencia de la advertencia de SmartScreen, el bloqueo no ofrece la opción de ejecutar el archivo de todas formas, y las preguntas frecuentes de Microsoft dicen que no hay forma de eludir Control Inteligente de Aplicaciones para una aplicación concreta.

Esto es lo que ocurrió al probar 7-ZSTar 26.05.1 en Windows 11 Pro 25H2 (compilación 26200.8037) con Control Inteligente de Aplicaciones activado:

- **Los instaladores `.msi` se bloquearon**, tanto el de todos los usuarios como el de por usuario. En un Windows en chino tradicional, Windows Installer mostró «系統禁用此安裝。請連絡系統管理員。», y una notificación de Seguridad de Windows dijo que Control Inteligente de Aplicaciones había bloqueado el archivo porque Windows no podía saber quién lo publicó y no es una aplicación que Windows conozca. No había ninguna opción para continuar, y `msiexec /i ... /qn` devolvió el error 1625. Ese mensaje es la cadena 1625 de Windows Installer; en un Windows en inglés la misma cadena dice "The system administrator has set policies to prevent this installation." (leída de los recursos en inglés de Windows Installer, no vista en pantalla).
- **Un programa del `.zip` sí se ejecutó.** `7zFM.exe`, extraído del `.zip` portátil, se inició con normalidad en la misma prueba. Que Windows deje ejecutar un programa sin firmar es una valoración propia de ese archivo, así que en tu equipo puede ser distinto.
- Justo después de activar Control Inteligente de Aplicaciones, el `.msi` se instaló durante unos minutos antes de empezar a bloquearse. No se encontró la causa, así que una instalación correcta justo después de activarlo no significa que el instalador esté permitido.

Así que en un equipo con Control Inteligente de Aplicaciones activado, **los instaladores no se pueden instalar**, y comprobar `SHA256SUMS` no cambia eso. Lo que sí lo cambia es desactivar Control Inteligente de Aplicaciones en la «Configuración de Control Inteligente de Aplicaciones» de la aplicación Seguridad de Windows (en el Windows en chino tradicional que se probó: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). En la prueba, elegir la opción Desactivado surtió efecto al instante, sin reiniciar, y los instaladores se instalaron después. Es un ajuste de todo el equipo y nada de lo aquí escrito te pide que lo cambies: la decisión es tuya, o de tu administrador en un equipo administrado.

También conviene saber de antemano si se puede volver a activar. Las preguntas frecuentes de Microsoft dicen que las actualizaciones recientes de Windows permiten volver a activar Control Inteligente de Aplicaciones sin una instalación limpia de Windows, así que en una versión sin ellas, desactivarlo puede ser permanente. En la compilación que se probó aquí, la opción para activarlo se seguía ofreciendo después de desactivarlo; es un resultado de prueba, no una promesa sobre tu versión.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Instalación

Tres paquetes, todos creados con `installer\Build-Package.ps1` (el de por usuario con `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Se instala para | todas las cuentas | la cuenta que instala | - |
| Menú contextual del Explorador de archivos | sí | sí, solo el menú clásico ([abajo](#el-paquete-por-usuario)) | no |
| Entrada en el Menú Inicio | sí | sí | no |
| Administrador necesario | sí | no | no |
| Desinstalación | *Aplicaciones instaladas* en Configuración | *Aplicaciones instaladas* en Configuración | eliminar la carpeta |

*Aplicaciones instaladas* es el nombre en Windows 11. Windows 10 llama a la misma página *Aplicaciones y características*, y en Windows 7 es *Programs and Features* en Control Panel (Panel de control).

Usa los paquetes que correspondan al propio Windows: x86 en Windows de 32 bits, x64 en Windows de 64 bits, arm64 en Windows on Arm (los paquetes arm64 se crean, pero nunca se han ejecutado). La extensión de shell x86 es de 32 bits y el Explorador de archivos de 64 bits no puede cargarla, así que en Windows de 64 bits el `-user.msi` x86 no tiene ningún menú contextual, y el `.msi` x86 solo lo tiene en Windows 11 y solo para las cuentas que registraron su paquete de Windows 11 (la que instaló, o una que ejecutó `-Register`, más abajo).

El MSI se instala en `Program Files\7-ZSTar`, siempre: a diferencia del paquete por usuario, no ofrece elegir carpeta e ignora `INSTALLFOLDER` en la línea de comandos, porque esa carpeta contiene un script que el instalador ejecuta como SYSTEM y una DLL que el Explorador de archivos de todos los usuarios carga, y una carpeta creada en otro sitio (bajo `C:\`, por ejemplo) es escribible por todos los usuarios. Registra su propio CLSID de extensión de shell y su propia colmena de registro `Software\7-ZSTar`, y llama `7-ZSTar` a cada clave del menú contextual, de modo que ni choca con las del 7-Zip oficial ni las elimina. Consulta [installer/GUIDS.md](../../installer/GUIDS.md).

Ejecuta un asistente de instalación normal (welcome, licence, setup type, optional feature tree, finish: bienvenida, licencia, tipo de instalación, árbol de funciones opcionales y finalización) y la instalación silenciosa sigue funcionando sin cambios (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), porque msiexec se salta toda la secuencia de interfaz en modo silencioso. El asistente está solo en inglés, también en un Windows configurado en otro idioma (visto en Windows 10 en chino tradicional; el `.msi` se compila sin otros idiomas), y en su página final *Launch 7-ZSTar File Manager* viene marcado de forma predeterminada.

### El menú contextual de Windows 11

En Windows 11 la entrada está en el menú de primer nivel, no escondida bajo *Mostrar Más opciones*, donde siguen estando el 7-Zip oficial y WinRAR. Windows 11 solo muestra allí una extensión de shell cuando viene con identidad de paquete, así que el MSI incluye, junto al programa, un pequeño paquete MSIX solo de identidad y lo registra durante la instalación. También se conserva el registro clásico. Es el que pone la entrada en el menú contextual de Windows 10 y Windows 7, cuyo menú tiene un único nivel y no tiene *Mostrar Más opciones*, y el que lo mantiene funcionando para quien haya restaurado el menú contextual antiguo.

Ese paquete está firmado con un **certificado autofirmado**, y el instalador lo coloca en `LocalMachine\TrustedPeople`: Windows no implementa un paquete cuya firma no pueda enlazar con algo de confianza. Al desinstalar se elimina el certificado junto con el paquete. En Windows 10 y Windows 7 el instalador no hace ninguna de las dos cosas: no añade ningún certificado y no registra ningún paquete, y el menú lo proporciona solo el registro clásico.

Si prefieres no confiar en un certificado autofirmado, rechaza solo esa parte y conserva todo lo demás:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Entonces obtienes solo el menú clásico, así que en Windows 11 la entrada de 7-ZSTar está en el menú contextual, bajo *Mostrar Más opciones*. Para activar más tarde la entrada de primer nivel, o para deshacerla después de una instalación normal:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Confiar en ese certificado significa que Windows también aceptará sin advertencia **cualquier otro** paquete firmado con la misma clave. Solo se usa para este paquete, y la desinstalación lo retira, pero eso es lo que aceptas: `SPARSE=0`, arriba, es la forma de rechazarlo.

El registro del paquete es por usuario, y el instalador solo lo ejecuta para quien instaló. Dos consecuencias:

- Una segunda cuenta en el mismo equipo tiene solo el menú clásico, hasta que ejecute ese mismo script con `-Register`.
- La desinstalación solo anula el registro de quien desinstala. Si lo registró otra persona, su registro sobrevive a la desinstalación y apunta a una carpeta que ya no existe; esa cuenta lo elimina con `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Limitación conocida: el menú de primer nivel solo se registra cuando la instalación se hace en una sesión interactiva con la sesión iniciada.** Instalar el `.msi` para todos los usuarios desde una sesión remota o no interactiva (por SSH, o una implementación silenciosa desde una herramienta de administración) informa igualmente de éxito, pero el paquete de Windows 11 no se registra, así que solo aparece el menú clásico bajo *Mostrar Más opciones*. En la prueba, `msiexec /i ... /qn` desde una sesión SSH (sesión 0) terminó con 0 mientras que `Setup-ShellIntegration.ps1` informó `registration failed: 0x80070005` (acceso denegado); el mismo `.msi` instalado desde la sesión de consola de un administrador se registró con normalidad.

`-Status` muestra lo que está y lo que no está en su sitio.

### El paquete por usuario

`7-ZSTar-<version>-<arch>-user.msi` se instala solo para la cuenta actual, en `%LOCALAPPDATA%\Programs\7-ZSTar`, sin ningún aviso del Control de cuentas de usuario (UAC). Todo lo que registra va bajo `HKCU`; el paquete no escribe nada en `HKLM` (salvo la contabilidad interna de Windows Installer). Lo que no hace como lo hace el paquete por equipo:

- **Sin menú de primer nivel en Windows 11.** En Windows 11, 7-ZSTar está en el menú contextual bajo *Mostrar Más opciones*. La entrada de primer nivel necesita que el certificado autofirmado sea de confianza en todo el equipo, lo cual requiere un administrador: medido en Windows 11, un certificado en `CurrentUser\TrustedPeople` no basta para que Windows implemente el paquete. Por eso el paquete por usuario la omite.
- **Solo uno de los dos por equipo.** Cada paquete se niega a instalarse mientras el otro esté instalado; desinstala uno antes de instalar el otro. El paquete por equipo solo ve la copia por usuario de la cuenta que lo ejecuta, así que la instalación por usuario de otra cuenta no se detecta.
- **La Directiva de grupo puede ocultar su menú.** Donde está establecido `EnforceShellExtensionSecurity`, el Explorador de archivos carga solo las extensiones de shell que figuran en la clave *Approved* de todo el equipo, en la que una instalación por usuario no puede escribir, así que el menú contextual no aparece. Usa allí el paquete por equipo.
- **Vaciar un formato en Herramientas > Opciones > Sistema también elimina la oferta de 7-ZSTar para ese formato.** Cuando vacías allí un formato (haz clic en su celda hasta que quede vacía y luego en Aceptar), el administrador de archivos elimina por completo las claves `HKCU\Software\Classes\.<ext>` y `7-ZSTar.<ext>`, y en una instalación por usuario esas claves también contienen lo que el paquete registró para Configuración > Aplicaciones > Aplicaciones predeterminadas y para la lista *Abrir con*. Entonces 7-ZSTar desaparece de *Abrir con* para ese formato, y Aplicaciones predeterminadas muestra una entrada en blanco para él. Reparar la instalación lo devuelve (vuelve a ejecutar el `.msi` y elige *Repair* (reparar)). Mejor aún, asigna los tipos de archivo en Aplicaciones predeterminadas en lugar de hacerlo en el administrador de archivos. El paquete por equipo tiene el mismo punto débil en un caso, descrito más abajo en las asociaciones de archivos.

### Asociaciones de archivos y qué hace la desinstalación con ellas

**Establécelas en Configuración > Aplicaciones > Aplicaciones predeterminadas.** En Windows 11, escribe 7-ZSTar allí y se muestran todos los formatos que puede abrir para asignarlos. En Windows 10, 7-ZSTar aparece en esa página bajo *Set defaults by app* (establecer valores predeterminados por aplicación), donde *Manage* (administrar) muestra sus formatos. Windows 7 no tiene la aplicación Configuración: 7-ZSTar aparece en Control Panel > Programas predeterminados > *Establecer programas predeterminados*, que es lo que *Aplicaciones predeterminadas* representa allí en esta guía. No se ha probado asignar formatos desde esas dos páginas. El instalador registra 7-ZSTar como aplicación de Programas predeterminados (un ProgID por formato con su icono y su comando de apertura, una entrada en la lista *Abrir con* de cada extensión y el bloque Capabilities que lee Windows), pero deliberadamente no reclama ningún tipo de archivo: qué programa abre tus archivos comprimidos lo decides tú, y eso es lo que mantiene a 7-ZSTar y al 7-Zip oficial fuera del camino el uno del otro. Aun así, Windows puede dirigir un formato a 7-ZSTar por su cuenta cuando ningún otro programa se ofrece a abrirlo: en los equipos con Windows 10 y Windows 7 que se probaron, donde nada más había registrado `.7z`, un archivo `.7z` mostraba el icono de 7-ZSTar y se abría con él al hacer doble clic, sin que Windows preguntara qué programa usar.

**Herramientas > Opciones > Sistema en el administrador de archivos casi no funciona en Windows 11**, y eso es una regla de Windows, no un error de aquí. Escribe un ProgID `7-ZSTar.<ext>` en `HKCU\Software\Classes`, y para cualquier extensión que el equipo ya conoce (todos los formatos de archivo comprimido lo son) Windows 11 lo ignora: `AssocQueryString` responde `Unknown` y el Explorador de archivos dibuja el icono genérico en blanco. Lo que respeta en su lugar es una clave `UserChoice` sellada con un hash que solo Windows puede calcular, y por eso la interfaz de Configuración es la única vía allí. Ninguna aplicación puede escribir una: ni 7-ZSTar, ni 7-Zip, ni ningún instalador. Windows 10 y Windows 7 se comportaron de otra manera en las pruebas: una vez establecidos `.7z` y `.zst` en el administrador de archivos, sin ningún otro programa elegido para ellos, `AssocQueryString` devolvió `7zFM.exe` para ambos.

**Vaciar un formato en su columna *Todos los usuarios* elimina el registro propio del paquete por equipo para ese formato.** Esa columna escribe en `HKLM\Software\Classes`, donde el paquete por equipo guarda los ProgID y las entradas de *Abrir con* que ofrece, y vaciar allí un formato (lo que requiere ejecutar el administrador de archivos con *Ejecutar como administrador*) elimina esas claves por completo, para todas las cuentas. Reparar restauró las mismas claves en el paquete por usuario; para este no se midió.

**Un icono que sigue en blanco después de cambiar algo** también puede deberse a la caché de iconos del Explorador de archivos, que no se da cuenta de que se ha reemplazado una DLL que ya tenía en caché; `ie4uinit.exe -show` no la borra de forma fiable. Cierra el Explorador de archivos, elimina `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` y vuelve a iniciarlo.

**La desinstalación elimina las asociaciones a las que llega**: los ProgID `7-ZSTar.*` de quien está desinstalando, y solo los tipos de archivo que siguen apuntando a ellos, de modo que un formato que mientras tanto se haya pasado a otro programa se deja como está. La desinstalación del paquete por equipo también deja intacto un ProgID que abre una copia de 7-ZSTar que todavía existe en otro lugar, una portátil del `.zip`, configurada con la opción **Herramientas > Opciones > Sistema** de esa propia copia. El paquete por usuario no puede: sus ProgID son esas mismas claves de `HKCU` (véase *El paquete por usuario*, arriba), y desinstalarlo las elimina, sin importar quién las escribió en último lugar. Dejarlas atrás haría que esos tipos apuntaran a un ProgID cuyo icono y comando son un ejecutable eliminado, es decir, un icono en blanco y un error al hacer doble clic. Las asociaciones de otras cuentas quedan fuera de alcance; esas cuentas pueden eliminar las suyas con `Setup-ShellIntegration.ps1 -RemoveAssociations` antes de que se quite el programa. `msiexec /x ... KEEPASSOC=1` omite este paso, y una actualización nunca lo realiza.

**Limitación conocida: las demás cuentas conservan las asociaciones que establecieron ellas mismas.** La desinstalación del paquete por equipo solo borra lo que la cuenta que ejecuta la desinstalación estableció en su propia columna (encabezada con el nombre de la cuenta) bajo **Herramientas > Opciones > Sistema** en el administrador de archivos. Cualquier otra cuenta que haya establecido allí asociaciones las conserva, apuntando al programa eliminado, así que al hacer doble clic en un archivo `.7z`, Windows pregunta qué programa usar. Cada cuenta debería borrar las suyas **antes** de la desinstalación, con

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

que elimina solo las entradas de 7-ZSTar, o bien volver a asignar los tipos después en Configuración > Aplicaciones > Aplicaciones predeterminadas. Hacerlo en cambio en el administrador de archivos significa hacer clic en cada celda de su propia columna que muestre 7-ZSTar hasta que quede vacía y luego en Aceptar; no selecciones todas las filas ni pulses "+", que aplica un solo estado a todas las filas seleccionadas y, por tanto, también borra los formatos que pertenecen a otro programa, como el 7-Zip oficial.

Las asociaciones establecidas en la columna **Todos los usuarios** no las toca en absoluto la limpieza de la desinstalación, y dejan a todas las cuentas apuntando al programa eliminado. Un administrador que haya establecido alguna debería vaciar esas celdas, desde un administrador de archivos ejecutado con *Ejecutar como administrador*, y luego hacer clic en Aceptar, antes de desinstalar; `-RemoveAssociations` no llega a esta columna. Vaciarla justo antes de una desinstalación es inofensivo aunque elimine allí el registro propio del paquete (arriba), ya que la desinstalación lo elimina de todos modos. El paquete por usuario no tiene el problema de las otras cuentas, y el 7-Zip oficial se comporta igual.

## Idiomas

Cada paquete incluye las traducciones de upstream, poco más de 90 idiomas. Elige uno en **Herramientas > Opciones > Lenguaje**; el MSI también permite omitirlos con la instalación *Custom* (personalizada). 7-ZSTar intenta seguir el idioma del sistema en el primer inicio, pero esa detección se rinde y se queda en inglés cuando los ajustes de Windows "language for non-Unicode programs" (idioma para programas que no son Unicode) y «Formato regional» no coinciden: elegir un idioma a mano siempre funciona.

Las cadenas que añadió el propio 7-ZSTar, es decir, los campos de nivel y de diccionario de zstd y los nombres de los nuevos formatos de archivo, no tienen traducción de upstream y siguen en inglés. La excepción son los botones **Donar** y **Sitio web** del cuadro de diálogo «Acerca de 7-ZSTar»: 67 de los 92 idiomas tienen una palabra para cada uno y los otros 25 muestran inglés (`Lang/UPSTREAM.md` los enumera).
Las traducciones se incorporan tal cual desde upstream, no se escriben aquí: consulta [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
