<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · **Español** · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [العربية](README.ar.md) · [Esperanto](README.eo.md)

**Un fork de 7-Zip más amigable para los usuarios actuales de Windows 11: menú contextual de primer nivel, compresión zstd y tar.zst en un solo paso.**

[Descargar](https://github.com/7zStar/7-ZSTar/releases/latest) · [Sitio web](https://www.7zstar.com/es/) · [Registro de cambios](../../CHANGELOG.md)

## Por qué 7-ZSTar

- **Olvídate de «Mostrar Más opciones».** Con el MSI para todos los usuarios, 7-ZSTar aparece en el primer nivel del menú contextual de Windows 11.
- **Un solo paso. Sin .tar en el disco.** Comprimir a tar.zst y extraerlo son un solo paso cada uno, sin escribir un .tar en ninguna de las dos direcciones. El 7-Zip oficial no puede crear un .tar.zst y lo extrae en dos pasos, pasando por un .tar.
- **10× más rápido que 7z.** Con carpetas de proyectos reales, tar.zst comprimió entre 10 y 18 veces más rápido que 7z.

## Velocidad

| Carpeta | Archivos | Tamaño original | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (binarios grandes) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst resultó entre un 15 y un 23 % más pequeño que zip, y sin ser más lento. Frente a 7z, en cambio, es entre un 15 y un 27 % más grande, así que si lo que más importa es el archivo más pequeño, 7z sigue siendo la mejor opción. Estas cifras son de compresión; al extraer, los tres tardaron más o menos lo mismo.

zip, 7z y tar.zst, todos con la configuración predeterminada. 7-ZSTar 26.05.1 x64 (7z.exe), un solo equipo (Intel Core Ultra 7 155H, SSD NVMe), tres carpetas de proyectos reales, mediana de 3 ejecuciones, 2026-11.

## Formatos

- **Compresión en un solo paso (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extracción en un solo paso (10):** esos 8, más tar.lzma y tar.Z
- **Códecs agregados:** zstd, brotli, lz4, lz5 y lizard, cada uno como formato independiente y como método dentro de .7z, además de fast-lzma2 como codificador LZMA2 alternativo.
- Siguen disponibles todos los formatos que 7-Zip ya admitía.

Al extraer tar.br, tar.lz4, tar.lz5, tar.liz o tar.Z sigue siendo un solo paso para ti, pero 7-ZSTar decodifica primero a un archivo intermedio y lo borra después.

## Línea de comandos

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

En PowerShell, pon el parámetro de formato entre comillas, como en `7z a "-ttar.zst" backup.tar.zst docs`. Sin ellas, PowerShell divide `-ttar.zst` en dos y 7z crea un archivo llamado `.zst`. El Símbolo del sistema (cmd) no necesita comillas.

## Descarga e instalación

| | Todos los usuarios `.msi` | Solo para ti `-user.msi` | Portátil `.zip` |
|---|---|---|---|
| Se instala para | Todas las cuentas del PC | La cuenta actual | No requiere instalación |
| Requiere permisos de administrador | Sí | No | No |
| Menú contextual | Primer nivel de Windows 11 | En «Mostrar Más opciones» | Ninguno |
| Entrada en el menú Inicio | Sí | Sí | No |

Cada uno viene en x64, x86 y arm64; elige el que corresponda a tu Windows: en Windows de 64 bits, es posible que los paquetes x86 no tengan menú contextual. Las compilaciones arm64 aún no se han probado en hardware real. 7-ZSTar se instala junto al 7-Zip oficial y ninguno afecta al otro.

**Windows puede mostrar una advertencia con estas descargas.** Los instaladores y programas no están firmados por una autoridad de certificación, así que Microsoft Defender SmartScreen puede detenerlos con una advertencia la primera vez que ejecutes uno, y en un PC con Windows 11 que tenga Smart App Control activado los instaladores `.msi` se bloquean por completo, sin opción de continuar. Eso no significa que el archivo tenga algún problema: cada release incluye un archivo `SHA256SUMS`, y con él puedes comprobar que lo que descargaste coincide con lo que se publicó. Cómo comprobarlo, qué significa Smart App Control para ti y cómo seguir una vez que la comprobación coincide está en [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**Sobre el menú de primer nivel:** Windows 11 solo deja que lleguen al primer nivel los programas con identidad de paquete, así que el MSI para todos los usuarios instala un pequeño paquete MSIX firmado con un certificado autofirmado y marca ese certificado como de confianza. Al desinstalar se quitan ambos. Si prefieres no confiar en él, instala con `msiexec /i 7-ZSTar-<versión>-<arquitectura>.msi SPARSE=0` y el menú se queda en «Mostrar Más opciones». El paquete se registra solo para la cuenta que ejecuta el instalador; las demás cuentas lo registran por separado.

Todos los detalles, incluidas las asociaciones de archivos y la desinstalación, están en [docs/INSTALL.md](../INSTALL.md) (por ahora solo en inglés).

## Limitaciones conocidas

- **Al desmarcar la casilla de integración con el shell se quita el registro del menú contextual.** En el administrador de archivos (`7zFM`), **Herramientas > Opciones > 7-ZSTar** tiene una casilla llamada «Integrar 7-ZSTar al menú contextual del shell». Igual que en el 7-Zip oficial, desmarcarla borra el registro de la extensión del shell (su clave `CLSID`) que creó el instalador, y la entrada de 7-ZSTar desaparece del menú contextual. Con el paquete para todos los usuarios puedes volver a marcarla si el administrador de archivos se ejecuta como administrador. Con el paquete para el usuario actual no se puede: al marcarla de nuevo aparece «Acceso denegado» y la entrada sigue sin aparecer. Para recuperarla, vuelve a ejecutar el `.msi` original y elige *Reparar*.
- **El menú de primer nivel solo se registra cuando la instalación se ejecuta en una sesión interactiva con sesión iniciada.** Si instalas el `.msi` para todos los usuarios desde una sesión remota o no interactiva (por SSH, o en un despliegue silencioso desde una herramienta de administración), la instalación sigue informando de que fue un éxito, pero el paquete de Windows 11 no se registra, así que solo aparece el menú clásico en «Mostrar Más opciones». Los detalles están en [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu).

## Requisitos del sistema

Windows 7 o Windows Server 2008 R2 y posteriores (x64, x86); en arm64, Windows 10 y posteriores. No hay que instalar nada más. Este mínimo sale de los requisitos de los paquetes; las versiones anteriores a Windows 11 no se han probado. En Linux hay una versión de línea de comandos que debes compilar tú; macOS no es compatible.

## Sobre este proyecto

7-ZSTar es un fork de 7-Zip más amigable para los usuarios actuales de Windows 11. El núcleo de 7-Zip es excelente, pero algunas cosas no han seguido el ritmo de cómo se trabaja ahora: Windows 11 lo esconde en «Mostrar Más opciones» y no puede comprimir a zstd. 7-ZSTar cubre esos huecos y deja todo lo demás como ya lo conoces.

## Documentación

Todos los paquetes incluyen `7-zip.chm`, el archivo de ayuda del 7-Zip oficial, sin modificar: **Ayuda > Contenidos** y F1 lo abren. En él dice «7-Zip» en todas partes y no cubre lo que agrega 7-ZSTar; para eso, consulta esta página y [CHANGELOG.md](../../CHANGELOG.md).

Si el archivo de ayuda no está junto al ejecutable, esas mismas entradas abren esta sección en línea (en inglés).

## Compilar desde el código fuente

Consulta [build/README.md](../../build/README.md). En resumen: VS2022 Build Tools (MSVC v143) y luego `pwsh build\Build.ps1`. Antes de incorporar una nueva versión de upstream, lee [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Donar

7-ZSTar es gratis, ayudes o no. Si te ha ahorrado algo de tiempo y quieres darme las gracias, puedes enviar criptomonedas a la dirección de abajo. El dinero es para mí, DraftingDreamer, para cubrir mis propios gastos de desarrollo; no compra funciones, ayuda ni ninguna promesa sobre lo que venga después.

Se acepta cualquier token de Ethereum o Polygon: ETH, POL, USDT, USDC u otro. Es la misma dirección en las dos redes.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Código QR de la dirección de donación">

- Solo se aceptan transferencias en Ethereum (ERC20) y Polygon. Si puedes usar cualquiera de las dos, Polygon suele tener comisiones más bajas.
- Esta es la única dirección oficial y nunca te pediré que envíes a otra dirección.
- Las transferencias no se pueden revertir, por lo que no hay reembolsos.

Darle una estrella a 7-ZSTar en GitHub o recomendárselo a un amigo también ayuda.

## Licencia

LGPL v3, consulta [LICENSE](../../LICENSE). Algunas partes tienen otras condiciones: la descompresión RAR, por ejemplo, lleva la restricción unRAR, así que una compilación con soporte para RAR no es puramente LGPL v3. La lista completa está en [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) y los avisos de derechos de autor de cada componente, en [NOTICE](../../NOTICE).

## Agradecimientos

7-ZSTar se apoya en los hombros de muchas personas. Gracias a todos los que han dedicado su tiempo a 7-Zip, a los algoritmos de compresión y al código abierto en general. Sin ellos, este software no existiría.
