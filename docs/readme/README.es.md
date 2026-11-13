<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · **Español** · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Si hay alguna diferencia con la versión en inglés, prevalece la versión en inglés.*

**Un fork de 7-Zip más amigable para los usuarios actuales de Windows 11: menú contextual de primer nivel, compresión zstd y tar.zst en un solo paso.**

[Descargar](https://github.com/7zStar/7-ZSTar/releases/latest) · [Sitio web](https://www.7zstar.com) · [Registro de cambios](../../CHANGELOG.md)

## Por qué 7-ZSTar

- **Olvídate de «Mostrar Más opciones».** En Windows 11, 7-ZSTar aparece directamente en el primer nivel del menú contextual.
- **tar.zst en un solo paso.** Comprime una carpeta a .tar.zst, o extrae uno, en un solo paso, sin dejar ningún .tar en el disco. El 7-Zip oficial no puede crear .tar.zst y lo extrae en dos pasos, pasando por un .tar.
- **Alrededor de 10× más rápido que 7z.** Con carpetas de proyectos reales, tar.zst comprimió entre 10 y 18 veces más rápido.

## Velocidad

| Carpeta | Archivos | Tamaño original | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (binarios grandes) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst resultó entre un 15 y un 23 % más pequeño que zip, y sin ser más lento. 7z sigue generando los archivos más pequeños (tar.zst fue entre un 15 y un 27 % más grande), pero tardó mucho más. Al extraer, los tres tardaron más o menos lo mismo.

Configuración predeterminada en los tres; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, SSD NVMe, mediana de 3 ejecuciones, 2026-11.

## Formatos

- **Comprimir en un solo paso:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extraer en un solo paso:** todos esos, más tar.lzma y tar.Z
- **Códecs añadidos:** zstd, brotli, lz4, lz5 y lizard (por sí solos o dentro de un .7z), además de fast-lzma2, un codificador LZMA2 alternativo
- Siguen funcionando todos los formatos que admite el 7-Zip oficial.

## Descarga

La mayoría de la gente querrá el `.msi` x64 para todos los usuarios, que está en [Versiones](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` para todos los usuarios | Solo para ti `-user.msi` | `.zip` portátil |
|---|---|---|---|
| Requiere permisos de administrador | Sí | No | No |
| Menú contextual | Primer nivel en Windows 11 | Menú clásico (en Windows 11, en «Mostrar Más opciones») | Ninguno |
| Entrada en el *Menú Inicio* | Sí | Sí | No |

Cada uno viene también para x86 y arm64; elige el que corresponda a tu Windows. En Windows de 64 bits, es posible que los paquetes x86 no tengan menú contextual, y las compilaciones arm64 aún no se han probado en hardware real. 7-ZSTar se instala junto al 7-Zip oficial sin afectarlo.

**Es posible que Windows te muestre una advertencia la primera vez.** Los archivos no tienen firma de código, así que SmartScreen puede detenerlos («Windows protegió su PC»; puede que tengas que desplegar la advertencia para ver *Ejecutar de todas formas*), y en Windows 11 con Control Inteligente de Aplicaciones activado, el `.msi` se bloquea por completo. Cada versión incluye un archivo `SHA256SUMS` con el que comprobar tu descarga. [La guía de instalación](../install/INSTALL.es.md#paquetes-sin-firmar-smartscreen-y-control-inteligente-de-aplicaciones) explica cómo, y qué hacer con Control Inteligente de Aplicaciones.

**Sobre el menú de primer nivel:** en Windows 11, el `.msi` para todos los usuarios añade un pequeño paquete firmado con un certificado autofirmado y confía en ese certificado; es lo que Windows exige para el primer nivel. Al desinstalar se quitan ambos. Si prefieres no hacerlo, instala con `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. El paquete se registra para la cuenta que ejecuta el instalador; las demás cuentas lo registran por separado.

Las asociaciones de archivos, la desinstalación y el paquete por usuario se tratan en la [guía de instalación](../install/INSTALL.es.md).

## Línea de comandos

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

En PowerShell, pon el parámetro entre comillas: `7z a "-ttar.zst" backup.tar.zst docs`. Sin ellas, PowerShell lo divide en dos y obtienes un archivo llamado `.zst`. En *Command Prompt (cmd)*, el símbolo del sistema, no hacen falta comillas.

## Conviene saber

- **Desactivar «Integrar 7-ZSTar al menú contextual del shell»** (administrador de archivos, **Herramientas > Opciones > 7-ZSTar**) quita la entrada del menú contextual, como en el 7-Zip oficial. Con el paquete para todos los usuarios, se vuelve a activar ejecutando el administrador de archivos con *Ejecutar como administrador*. Con el paquete por usuario no se puede («Acceso denegado.»); ejecuta de nuevo el `.msi` y elige *Repair* (reparar).
- **Las instalaciones silenciosas o remotas en Windows 11** (por SSH, o desde una herramienta de implementación) se completan, pero la entrada de primer nivel no se registra, así que 7-ZSTar solo aparece en «Mostrar Más opciones». [Más detalles en la guía de instalación](../install/INSTALL.es.md#el-menú-contextual-de-windows-11).
- **Extraer tar.br, tar.lz4, tar.lz5, tar.liz o tar.Z** sigue siendo un solo paso para ti, pero pasa por un archivo temporal que se elimina después.

## Requisitos del sistema

Windows 7 / Server 2008 R2 o posterior (x64, x86), o Windows 10 o posterior en arm64. No hace falta instalar nada más. Probado en Windows 7 SP1 de 64 bits (con las actualizaciones posteriores instaladas), Windows 10 y Windows 11; [qué se probó](../install/INSTALL.es.md#requisitos-del-sistema). En Linux hay una compilación de línea de comandos que debes compilar tú; macOS no es compatible.

## Documentación

**Ayuda > Contenidos** y F1 abren `7-zip.chm`, el archivo de ayuda del 7-Zip oficial. Dice «7-Zip» en todas partes y no cubre lo que añade 7-ZSTar; eso lo encuentras en esta página y en el [registro de cambios](../../CHANGELOG.md). Si falta el archivo de ayuda, las mismas entradas abren esta sección en línea.

Para compilar 7-ZSTar tú mismo, consulta [build/README.md](../../build/README.md); antes de incorporar una nueva versión upstream, lee [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Donar

7-ZSTar es gratis, aportes o no. Si te ha ahorrado algo de tiempo y quieres darme las gracias, puedes enviar criptomonedas a la dirección de abajo. El dinero es para mí, DraftingDreamer, para cubrir mis propios gastos de desarrollo; no compra funciones, asistencia ni ninguna promesa sobre lo que venga después.

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

LGPL v3, consulta [LICENSE](../../LICENSE). Algunas partes tienen otras condiciones: la descompresión de RAR lleva la restricción unRAR, así que una compilación con compatibilidad con RAR no es puramente LGPL v3. La lista completa está en [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) y los avisos de copyright, en [NOTICE](../../NOTICE).

Gracias a todas las personas que han dedicado su tiempo a 7-Zip, a los algoritmos de compresión y al código abierto en general. Sin ustedes, 7-ZSTar no existiría.
