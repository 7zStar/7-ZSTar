<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · **Italiano** · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*In caso di differenze con la versione inglese, fa fede la versione inglese.*

**Un fork di 7-Zip più adatto a chi usa Windows 11 oggi: il menu contestuale al primo livello, la compressione zstd e tar.zst in un solo passaggio.**

[Scarica](https://github.com/7zStar/7-ZSTar/releases/latest) · [Sito web](https://www.7zstar.com) · [Cronologia delle modifiche](../../CHANGELOG.md)

## Perché usare 7-ZSTar

- **Basta con «Mostra altre opzioni».** Su Windows 11, 7-ZSTar sta direttamente al primo livello del menu contestuale.
- **tar.zst in un solo passaggio.** Comprimi una cartella in .tar.zst, o ne estrai uno, in un solo passaggio, senza lasciare nessun .tar sul disco. Il 7-Zip ufficiale non sa creare .tar.zst e lo estrae in due passaggi, passando da un .tar.
- **Circa 10× più veloce di 7z.** Su cartelle di progetti reali, tar.zst ha compresso da 10 a 18 volte più in fretta.

## Velocità

| Cartella | File | Dimensione originale | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (file binari di grandi dimensioni) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst è risultato dal 15 al 23% più piccolo di zip, e non più lento. 7z crea ancora i file più piccoli (tar.zst era dal 15 al 27% più grande), ma ha impiegato molto più tempo. L’estrazione ha richiesto più o meno lo stesso tempo con tutti e tre.

Impostazioni predefinite per tutti e tre; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, SSD NVMe, mediana di 3 esecuzioni, 2026-11.

## Formati

- **Comprimi in un solo passaggio:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Estrai in un solo passaggio:** tutti quelli sopra, più tar.lzma e tar.Z
- **Codec aggiunti:** zstd, brotli, lz4, lz5 e lizard (da soli o dentro un .7z), più fast-lzma2, un encoder LZMA2 alternativo
- Tutti i formati gestiti dal 7-Zip ufficiale continuano a funzionare.

## Scarica

Per la maggior parte delle persone va bene l’`.msi` x64 per tutti gli utenti, dalla pagina [Release](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` per tutti gli utenti | Solo per te `-user.msi` | `.zip` portatile |
|---|---|---|---|
| Richiede privilegi di amministratore | Sì | No | No |
| Menu contestuale | Primo livello su Windows 11 | Menu classico (su Windows 11 sotto «Mostra altre opzioni») | Nessuno |
| Voce nel *Menu Start* | Sì | Sì | No |

Ognuno è disponibile anche per x86 e arm64; scegli quello che corrisponde al tuo Windows. Su Windows a 64 bit i pacchetti x86 potrebbero non avere il menu contestuale, e le build arm64 non sono ancora state provate su hardware reale. 7-ZSTar si installa accanto al 7-Zip ufficiale senza influire su di esso.

**La prima volta Windows potrebbe mostrare un avviso.** I file non sono firmati digitalmente, quindi SmartScreen può bloccarli («PC protetto da Windows»; potrebbe essere necessario espandere l’avviso per vedere «Esegui comunque»), e su Windows 11 con Controllo intelligente delle app attivato l’`.msi` viene bloccato del tutto. Ogni release ha un file `SHA256SUMS` con cui confrontare il download. [Le istruzioni di installazione](../install/INSTALL.it.md#pacchetti-non-firmati-smartscreen-e-controllo-intelligente-delle-app) spiegano come, e cosa fare con Controllo intelligente delle app.

**Il menu al primo livello:** su Windows 11, l’`.msi` per tutti gli utenti aggiunge un piccolo pacchetto firmato con un certificato autofirmato e considera attendibile quel certificato; è ciò che Windows richiede per il primo livello. La disinstallazione rimuove entrambi. Se preferisci non farlo, installa con `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Il pacchetto viene registrato per l’account che esegue l’installer; gli altri account lo registrano separatamente.

Le associazioni di file, la disinstallazione e il pacchetto per singolo utente sono descritti nelle [istruzioni di installazione](../install/INSTALL.it.md).

## Riga di comando

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

In PowerShell, metti l’opzione tra virgolette: `7z a "-ttar.zst" backup.tar.zst docs`. Senza virgolette PowerShell la divide in due e ottieni un file chiamato `.zst`. Nel Prompt dei comandi (cmd) di Windows non servono virgolette.

## Da sapere

- **Disattivare «Integra 7-ZSTar nel menù contestuale della shell»** (file manager, **Strumenti > Opzioni > 7-ZSTar**) rimuove la voce dal menu contestuale, come nel 7-Zip ufficiale. Con il pacchetto per tutti gli utenti, per riattivarla basta avviare il file manager con *Esegui come amministratore*. Con il pacchetto per singolo utente non si può («Accesso negato.»); esegui di nuovo l’`.msi` e scegli *Repair* (ripristina l’installazione).
- **Le installazioni silenziose o da remoto su Windows 11** (via SSH, o da uno strumento di distribuzione) riescono, ma la voce al primo livello non viene registrata, quindi 7-ZSTar compare solo sotto «Mostra altre opzioni». [Altri dettagli nelle istruzioni di installazione](../install/INSTALL.it.md#il-menu-contestuale-di-windows-11).
- **Estrarre tar.br, tar.lz4, tar.lz5, tar.liz o tar.Z** resta un solo passaggio per te, ma passa da un file temporaneo che poi viene eliminato.

## Requisiti di sistema

Windows 7 / Server 2008 R2 o successivo (x64, x86), oppure Windows 10 o successivo su arm64. Non serve installare altro. Provato su Windows 7 SP1 a 64 bit (con gli aggiornamenti successivi installati), Windows 10 e Windows 11; [cosa è stato provato](../install/INSTALL.it.md#requisiti-di-sistema). Su Linux c’è una build da riga di comando che devi compilare tu; macOS non è supportato.

## Documentazione

**Aiuto > Guida** e F1 aprono `7-zip.chm`, il file della guida del 7-Zip ufficiale. Dice «7-Zip» dappertutto e non descrive ciò che 7-ZSTar aggiunge; lo trovi in questa pagina e nella [cronologia delle modifiche](../../CHANGELOG.md). Se il file della guida manca, le stesse voci aprono questa sezione online.

Per compilare 7-ZSTar da solo, vedi [build/README.md](../../build/README.md); prima di unire una nuova release upstream, leggi [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Dona

7-ZSTar si può usare gratis, che tu contribuisca o no. Se ti ha fatto risparmiare un po’ di tempo e vuoi ringraziarmi, puoi inviare criptovalute all’indirizzo qui sotto. Vanno a me, DraftingDreamer, per le mie spese di sviluppo e non danno diritto a funzionalità, assistenza o impegni su ciò che verrà.

Va bene qualsiasi token su Ethereum o Polygon: ETH, POL, USDT, USDC o altro. L’indirizzo è lo stesso su entrambe le reti.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Codice QR dell’indirizzo per le donazioni">

- Sono accettati solo trasferimenti su Ethereum (ERC20) e Polygon. Se puoi scegliere, di solito Polygon ha commissioni più basse.
- Questo è l’unico indirizzo ufficiale e non ti chiederò mai di inviare a un altro indirizzo.
- I trasferimenti non si possono annullare, quindi non è possibile rimborsarli.

Anche mettere una stella a 7-ZSTar su GitHub o parlarne con un amico è un aiuto.

## Licenza

LGPL v3, vedi [LICENSE](../../LICENSE). Alcune parti hanno condizioni diverse: la decompressione RAR è soggetta alla restrizione unRAR, quindi una build con supporto RAR non è puramente LGPL v3. L’elenco completo è in [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) e le note sul copyright sono in [NOTICE](../../NOTICE).

Grazie a tutti coloro che hanno dedicato il proprio tempo a 7-Zip, agli algoritmi di compressione e all’open source in generale. Senza di voi 7-ZSTar non esisterebbe.
