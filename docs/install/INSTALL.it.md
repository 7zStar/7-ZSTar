<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Installare 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · **Italiano** · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*In caso di differenze con la versione inglese, fa fede la versione inglese.*

Questa pagina approfondisce la versione breve del [README](../readme/README.it.md): requisiti di sistema, l'avviso di SmartScreen, Controllo intelligente delle app e come verificare un download, i tre pacchetti, il menu contestuale di Windows 11, le associazioni di file e la disinstallazione.

## Requisiti di sistema

**Windows 7 o Windows Server 2008 R2, x64 o x86. Su arm64, Windows 10.**
Non serve nient'altro: il runtime C è collegato staticamente (`-MT`), quindi i binari non importano altro che le DLL di Windows stesso: nessun pacchetto ridistribuibile, nessun .NET.

Questo requisito minimo è *dedotto* da ciò che richiedono i pacchetti, ed è stato verificato su Windows 7 SP1 con gli aggiornamenti successivi installati (PowerShell 5.1 compreso), su Windows 10 22H2 e su Windows 11, tutti a 64 bit. Su Windows 7 e 10 la verifica ha riguardato l'installazione e la disinstallazione dell'`.msi` x64 per tutti gli utenti e per singolo utente, la procedura guidata di installazione, lo `.zip` x64, ogni codec aggiunto e ogni formato tar a un solo passaggio, il menu contestuale, le associazioni di file e il file della guida, oltre all'`.msi` e allo `.zip` x86 eseguiti su Windows a 64 bit. Nient'altro è stato provato su Windows: né Windows 8 o 8.1, né Windows Server, né Windows a 32 bit, né hardware arm64, né Windows 7 senza quegli aggiornamenti. Il requisito minimo è inoltre più alto di quello del 7-Zip upstream, i cui binari si caricano ancora su Windows XP. Tre cose lo portano a questo livello, e la seconda è quella che nessuna impostazione di compilazione può annullare:

- L'`.msi` dichiara `InstallerVersion="500"`, e Windows Installer 5.0 è stato distribuito "with Windows Server 2008 R2 and later and Windows 7 and later" (cioè con Windows Server 2008 R2 e versioni successive e con Windows 7 e versioni successive) ([Microsoft][msi-versions]). Lo `.zip` portabile non passa da Windows Installer, ma vedi i due punti successivi.
- **zstd e fast-lzma2 usano una sincronizzazione che esiste solo da Vista in poi.** Entrambi forzano `_WIN32_WINNT 0x0600` nei propri header e chiamano direttamente `InitializeConditionVariable` / `SleepConditionVariableCS`, quindi `7z.dll` e `7za.exe`, i due binari con i codec compilati dentro, importano quattro funzioni che Windows XP e Server 2003 non hanno. Il `7z.dll` di upstream non ne importa nessuna.
- La toolchain: questi file sono compilati con Visual Studio 2022, i cui target supportati sono Windows 7 e successivi; Vista e Server 2008 sono "No" ([Microsoft][vs-targeting]). La versione del sottosistema collegata è 6.0 su x64 e x86 e 6.2 su arm64, e Windows su arm64 parte comunque da Windows 10.

Windows Vista e Server 2008 restano a metà strada: i binari si caricherebbero, ma la toolchain non li supporta, il programma di installazione non parte e 7-ZSTar non è testato su di essi.

**Linux è supportato solo come build da riga di comando; macOS non è supportato.**
Il fork compila un `7zz` nativo (il programma console `Alone2`) con gcc, tramite un proprio makefile che include quelli di upstream senza modificarne nessuno:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
È stato compilato e provato solo su Ubuntu 24.04 con gcc 13.3 (x86-64): la compilazione non produce avvisi con i flag di upstream, lo smoke test da 77 verifiche passa, e i 25 vettori di interoperabilità creati su Windows e i 37 creati su Linux danno gli stessi esiti che su Windows. I due file del fork toccati dal port si compilano ancora senza modifiche su Windows (build x64 pulita, smoke test e rilettura di interoperabilità passano tutti). Non c'è nessuna GUI. Gli altri target Linux di upstream (`7za`, `7zr`, `7z.so`) non sono supportati: nelle loro liste di oggetti gcc manca ciò che serve alle modifiche del fork ai gestori di upstream, quindi si prevede che falliscano al link. Altre architetture, distribuzioni e compilatori non sono stati verificati, e macOS non è mai stato compilato, quindi non si può indicare nessun `MACOSX_DEPLOYMENT_TARGET`. I passaggi di compilazione, i test e i limiti noti sono in `build/linux/README.md`; l'interoperabilità con gli strumenti Linux è in `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Pacchetti non firmati, SmartScreen e Controllo intelligente delle app

**Gli installer e i programmi di una release di 7-ZSTar non sono firmati digitalmente da un'autorità di certificazione**, e questo progetto non possiede alcun certificato di firma del codice. Windows quindi non può sapere chi ha pubblicato il file, e quando esegui l'`.msi`, o un programma dello `.zip`, per la prima volta, Microsoft Defender SmartScreen può fermarlo con un avviso. La documentazione per sviluppatori di Microsoft elenca "No signature" (nessuna firma) tra i casi che mostrano un avviso dal titolo "PC protetto da Windows" ("Windows protected your PC" nel testo di Microsoft), in cui l'utente deve scegliere "Run anyway" ("Esegui comunque") prima che l'app venga eseguita ([Microsoft][smartscreen-rep]). I criteri aziendali possono eliminare del tutto questa scelta; su un PC di questo tipo, rivolgiti a chi lo gestisce.

L'unica cosa di una release che *è* firmata è il piccolo pacchetto che porta 7-ZSTar al primo livello del menu contestuale di Windows 11, dentro l'`.msi` per tutti gli utenti. Il suo certificato è autofirmato e generato durante la compilazione di quel solo pacchetto, quindi non è la firma di un'autorità di certificazione e non dice nulla su chi ha compilato il pacchetto; vedi [il menu contestuale di Windows 11](#il-menu-contestuale-di-windows-11) per cosa fa e come rifiutarlo.

L'avviso non dimostra che un file sia dannoso, e la sua assenza non dimostrerebbe che un file sia sicuro. Quello che puoi verificare tu è che la tua copia sia esattamente quella pubblicata nella pagina della release. Ogni release include un file chiamato `SHA256SUMS`: una riga per pacchetto, con un hash SHA-256 seguito dal nome del file.

1. Scarica il pacchetto e `SHA256SUMS` dalla stessa pagina della release, nella stessa cartella.
2. Apri PowerShell in quella cartella e confronta. Sostituisci il nome con quello del file che hai scaricato:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` significa che gli hash sono identici. Per guardarli tu stesso, esegui invece
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` e cerca lo stesso
   nome di file in `SHA256SUMS`; il confronto ignora maiuscole e minuscole.
3. Se ottieni `False`, o il nome del file non è in `SHA256SUMS`, non eseguirlo: elimina il file e scaricalo di nuovo. Se ancora non corrisponde, segnalalo come descritto in [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` copre solo i file caricati in quella release. Compilare tu stesso lo stesso tag produce hash diversi (il pacchetto del menu contestuale viene firmato con un nuovo certificato a ogni compilazione), e il codice sorgente è pubblicato con ogni release se preferisci compilarlo: vedi [build/README.md](../../build/README.md).

Quando gli hash coincidono e ti fidi della provenienza del file:

- **`.msi`**: avvialo normalmente. Se SmartScreen lo ferma, scegli l'opzione per eseguirlo comunque ("Run anyway" su un Windows in lingua inglese, "Esegui comunque" su un Windows in italiano). Può essere necessario prima espandere la finestra dell'avviso: sul computer con Windows 10 provato, offriva solo un pulsante per non eseguire il file finché non si faceva clic sul collegamento sotto il suo messaggio. L'`.msi` per tutti gli utenti chiede poi l'approvazione di un amministratore come qualunque altro installer.
- **`.zip`**: estrailo e avvia `7zFM.exe` o `7z.exe` dalla cartella. Anche i programmi al suo interno non sono firmati, quindi Windows può mostrare lo stesso avviso la prima volta che avvii ciascuno.

SmartScreen avvisa in base a quanto un file è conosciuto, non solo in base alle firme; un file scaricato da poche persone può far scattare l'avviso anche se è firmato. Niente di quanto descritto qui cambia questo, e nessuno dei passaggi sopra disattiva SmartScreen.

### Controllo intelligente delle app su Windows 11

Su alcuni PC con Windows 11 è attivata una protezione più rigida chiamata **Controllo intelligente delle app**. Quando è attivata, Windows blocca i file non firmati a meno che il servizio cloud di Microsoft non possa garantire per loro, e una nuova release di solito non ha alcuna registrazione di questo tipo ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). A differenza dell'avviso di SmartScreen, il blocco non offre l'opzione di eseguire comunque il file, e le FAQ di Microsoft dicono che non c'è modo di aggirare Controllo intelligente delle app per una singola app.

Cosa è successo provando 7-ZSTar 26.05.1 su Windows 11 Pro 25H2 (build 26200.8037) con Controllo intelligente delle app attivato:

- **I programmi di installazione `.msi` sono stati bloccati**, sia quello per tutti gli utenti sia quello per singolo utente. Su un Windows in cinese tradizionale, Windows Installer ha mostrato «系統禁用此安裝。請連絡系統管理員。», e una notifica di Sicurezza di Windows ha detto che Controllo intelligente delle app aveva bloccato il file perché Windows non poteva sapere chi lo avesse pubblicato e non è un'app che Windows conosce. Non c'era nessuna opzione per continuare, e `msiexec /i ... /qn` ha restituito l'errore 1625. Quel messaggio è la stringa 1625 di Windows Installer; su un Windows in lingua inglese la stessa stringa recita "The system administrator has set policies to prevent this installation." (letta dalle risorse inglesi di Windows Installer, non vista sullo schermo).
- **Un programma dello `.zip` è stato eseguito.** `7zFM.exe`, estratto dallo `.zip` portabile, si è avviato normalmente nello stesso test. Se Windows lascia eseguire un programma non firmato è una sua valutazione di quel file, quindi sul tuo PC può essere diverso.
- Subito dopo l'attivazione di Controllo intelligente delle app, l'`.msi` si è installato per qualche minuto prima di cominciare a essere bloccato. La causa non è stata trovata, quindi un'installazione riuscita subito dopo l'attivazione non significa che l'installer sia consentito.

Quindi su un PC dove Controllo intelligente delle app è attivato, **gli installer non si possono installare**, e controllare `SHA256SUMS` non cambia nulla. Cambia invece disattivare Controllo intelligente delle app nelle Impostazioni di Controllo intelligente delle app dell'app Sicurezza di Windows (sul Windows in cinese tradizionale provato: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). Nel test, scegliere l'opzione Disattivato ha avuto effetto subito, senza riavvio, e poi gli installer si sono installati. È un'impostazione dell'intero PC e nulla qui ti chiede di cambiarla: la decisione spetta a te, o al tuo amministratore su un PC gestito.

Vale la pena sapere prima anche se si può riattivare. Le FAQ di Microsoft dicono che gli aggiornamenti recenti di Windows permettono di riattivare Controllo intelligente delle app senza una reinstallazione pulita di Windows, quindi su una versione senza quegli aggiornamenti disattivarlo può essere permanente. Nella build provata qui l'opzione per attivarlo veniva ancora offerta dopo averlo disattivato; è un risultato di test, non una promessa sulla tua versione.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installazione

Tre pacchetti, tutti creati da `installer\Build-Package.ps1` (quello per singolo utente con `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Si installa per | tutti gli account | l'account che installa | - |
| Menu contestuale di Explorer | sì | sì, solo menu classico ([sotto](#il-pacchetto-per-utente)) | no |
| Voce nel *Start menu* (menu Start) | sì | sì | no |
| Richiede un amministratore | sì | no | no |
| Disinstallazione | *App installate* in Impostazioni | *App installate* in Impostazioni | eliminare la cartella |

*App installate* è il nome in Windows 11. Windows 10 chiama la stessa pagina *App e funzionalità*, e su Windows 7 è *Programs and Features* nel Control Panel (Pannello di controllo).

Usa i pacchetti che corrispondono a Windows stesso: x86 su Windows a 32 bit, x64 su Windows a 64 bit, arm64 su Windows on Arm (i pacchetti arm64 vengono creati ma non sono mai stati eseguiti). L'estensione della shell x86 è a 32 bit e Explorer a 64 bit non può caricarla, quindi su Windows a 64 bit l'`-user.msi` x86 non ha alcun menu contestuale, e l'`.msi` x86 ne ha uno solo su Windows 11 e solo per gli account che hanno registrato il suo pacchetto per Windows 11 (quello che ha installato, o uno che ha eseguito `-Register`, vedi sotto).

L'MSI si installa in `Program Files\7-ZSTar`, sempre: a differenza del pacchetto per singolo utente non offre la scelta della cartella e ignora `INSTALLFOLDER` sulla riga di comando, perché quella cartella contiene uno script che l'installer esegue come SYSTEM e una DLL che l'Explorer di ogni utente carica, e una cartella creata altrove (sotto `C:\`, per esempio) è scrivibile da tutti gli utenti. Registra il proprio CLSID di estensione della shell e il proprio hive di registro `Software\7-ZSTar`, e dà a ogni chiave del menu contestuale il nome `7-ZSTar`: quindi non entra in conflitto con quelle del 7-Zip ufficiale né le rimuove. Vedi [installer/GUIDS.md](../../installer/GUIDS.md).

Esegue una normale procedura guidata di installazione (welcome, licence, setup type, optional feature tree, finish: benvenuto, licenza, tipo di installazione, albero delle funzionalità opzionali, fine) e l'installazione silenziosa funziona ancora invariata (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), perché msiexec salta l'intera sequenza dell'interfaccia in modalità silenziosa. La procedura guidata è solo in inglese, anche su un Windows impostato su un'altra lingua (visto su Windows 10 in cinese tradizionale; l'`.msi` è compilato senza altre lingue), e nella sua pagina finale *Launch 7-ZSTar File Manager* è spuntato per impostazione predefinita.

### Il menu contestuale di Windows 11

Su Windows 11 la voce è nel menu al primo livello, non nascosta sotto *Mostra altre opzioni* dove stanno ancora il 7-Zip ufficiale e WinRAR. Windows 11 elenca un'estensione della shell lì solo se arriva con un'identità di pacchetto, quindi l'MSI include accanto al programma un piccolo pacchetto MSIX con la sola identità e lo registra durante l'installazione. Viene mantenuta anche la registrazione classica. È quella che mette la voce nel menu contestuale su Windows 10 e Windows 7, il cui menu ha un solo livello e nessun *Mostra altre opzioni*, ed è quella che la fa continuare a funzionare per chi ha ripristinato il vecchio menu contestuale.

Quel pacchetto è firmato con un **certificato autofirmato**, e l'installer lo mette in `LocalMachine\TrustedPeople`: Windows non distribuisce un pacchetto la cui firma non risale a qualcosa di attendibile. La disinstallazione rimuove il certificato insieme al pacchetto. Su Windows 10 e Windows 7 l'installer non fa né l'una né l'altra cosa: non aggiunge nessun certificato e non registra nessun pacchetto, e il menu è fornito dalla sola registrazione classica.

Se preferisci non considerare attendibile un certificato autofirmato, rifiuta solo quella parte e tieni tutto il resto:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Così ottieni solo il menu classico, quindi su Windows 11 la voce di 7-ZSTar è nel menu contestuale sotto *Mostra altre opzioni*. Per attivare più tardi la voce al primo livello, o per annullarla dopo un'installazione normale:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Considerare attendibile quel certificato significa che Windows accetterà senza avviso anche **qualsiasi altro** pacchetto firmato con la stessa chiave. Viene usato solo per questo pacchetto, e la disinstallazione lo toglie di nuovo, ma è ciò che accetti: `SPARSE=0` qui sopra è il modo per rifiutarlo.

La registrazione del pacchetto è per singolo utente, e l'installer la esegue solo per chi ha installato. Due conseguenze:

- Un secondo account sullo stesso computer ha solo il menu classico, finché non esegue lo stesso script con `-Register`.
- La disinstallazione annulla la registrazione solo per chi disinstalla. Se l'ha registrato qualcun altro, la sua registrazione sopravvive alla disinstallazione e punta a una cartella che non esiste più; quell'account la rimuove con `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Limitazione nota: il menu al primo livello viene registrato solo quando l'installazione avviene in una sessione interattiva con accesso effettuato.** Installare l'`.msi` per tutti gli utenti da una sessione remota o non interattiva (via SSH, o una distribuzione silenziosa da uno strumento di gestione) segnala comunque successo, ma il pacchetto per Windows 11 non viene registrato, quindi compare solo il menu classico sotto *Mostra altre opzioni*. Nel test, `msiexec /i ... /qn` da una sessione SSH (sessione 0) è terminato con 0 mentre `Setup-ShellIntegration.ps1` ha riportato `registration failed: 0x80070005` (accesso negato); lo stesso `.msi` installato dalla sessione console di un amministratore si è registrato normalmente.

`-Status` mostra cosa c'è e cosa no.

### Il pacchetto per utente

`7-ZSTar-<version>-<arch>-user.msi` si installa solo per l'account corrente, in `%LOCALAPPDATA%\Programs\7-ZSTar`, senza richiesta di Controllo dell'account utente (UAC). Tutto ciò che registra va sotto `HKCU`; il pacchetto non scrive nulla in `HKLM` (a parte la contabilità interna di Windows Installer). Ecco cosa non fa come lo fa il pacchetto per computer:

- **Nessun menu al primo livello di Windows 11.** Su Windows 11, 7-ZSTar è nel menu contestuale sotto *Mostra altre opzioni*. La voce al primo livello richiede che il certificato autofirmato sia considerato attendibile a livello di computer, cosa che richiede un amministratore: misurato su Windows 11, un certificato in `CurrentUser\TrustedPeople` non basta perché Windows distribuisca il pacchetto. Per questo il pacchetto per singolo utente non la include.
- **Uno solo dei due per computer.** Ogni pacchetto rifiuta di installarsi finché è installato l'altro; disinstalla uno prima di installare l'altro. Il pacchetto per computer vede solo la copia per singolo utente dell'account che lo esegue, quindi l'installazione per singolo utente di un altro account non viene rilevata.
- **Il menu può essere nascosto dai Criteri di gruppo.** Dove è impostato `EnforceShellExtensionSecurity`, Explorer carica solo le estensioni della shell elencate sotto la chiave *Approved* a livello di computer, che un'installazione per singolo utente non può scrivere, quindi il menu contestuale non compare. Lì usa il pacchetto per computer.
- **Cancellare un formato in Strumenti > Opzioni > Sistema rimuove anche l'offerta di 7-ZSTar per quel formato.** Quando cancelli lì un formato (fai clic sulla sua cella finché è vuota, poi OK), il file manager elimina per intero le chiavi `HKCU\Software\Classes\.<ext>` e `7-ZSTar.<ext>`, e in un'installazione per singolo utente quelle chiavi contengono anche ciò che il pacchetto ha registrato per Impostazioni > App > App predefinite e per l'elenco *Apri con*. 7-ZSTar sparisce quindi da *Apri con* per quel formato, e App predefinite mostra per esso una voce vuota. Riparare l'installazione la ripristina (esegui di nuovo l'`.msi` e scegli *Repair*, cioè ripara). Meglio ancora, assegna i tipi di file in App predefinite invece che nel file manager. Il pacchetto per computer ha lo stesso punto debole in un caso, descritto sotto nelle associazioni di file.

### Associazioni di file e cosa succede disinstallando

**Impostale in Impostazioni > App > App predefinite.** Su Windows 11, digita 7-ZSTar lì e ogni formato che può aprire viene elencato per l'assegnazione. Su Windows 10, 7-ZSTar è elencato sotto *Set defaults by app* in quella pagina, dove *Manage* mostra i suoi formati. Windows 7 non ha l'app Impostazioni: 7-ZSTar è elencato in Control Panel > Default Programs > *Set your default programs*, che è ciò che *App predefinite* indica in questa guida lì. Assegnare i formati da quelle due pagine non è stato provato. L'installer registra 7-ZSTar come applicazione di Default Programs (Programmi predefiniti): un ProgID per formato con la sua icona e il comando di apertura, una voce nell'elenco *Apri con* di ogni estensione e il blocco Capabilities che Windows legge, ma di proposito non rivendica nessun tipo di file: quale programma apre i tuoi archivi lo decidi tu, ed è ciò che tiene 7-ZSTar e il 7-Zip ufficiale fuori dai rispettivi percorsi. Windows può comunque indirizzare da sé un formato a 7-ZSTar quando nessun altro programma si offre di aprirlo: sui computer con Windows 10 e Windows 7 provati, dove nient'altro aveva registrato `.7z`, un file `.7z` mostrava l'icona di 7-ZSTar e si apriva con esso al doppio clic, senza che Windows chiedesse quale programma usare.

**Strumenti > Opzioni > Sistema nel file manager per lo più non funziona su Windows 11**, ed è una regola di Windows, non un bug di 7-ZSTar. Scrive un ProgID `7-ZSTar.<ext>` in `HKCU\Software\Classes`, e per qualunque estensione che il computer già conosce (ogni formato di archivio lo è) Windows 11 lo ignora: `AssocQueryString` risponde `Unknown` ed Explorer disegna la generica icona vuota. Quello che onora invece è una chiave `UserChoice` contrassegnata con un hash che solo Windows può calcolare, ed è per questo che l'interfaccia di Impostazioni è l'unica via lì. Nessuna applicazione può scriverne una: né 7-ZSTar, né 7-Zip, né alcun installer. Windows 10 e Windows 7 si sono comportati diversamente nei test: una volta impostati `.7z` e `.zst` nel file manager, senza nessun altro programma scelto per essi, `AssocQueryString` ha restituito `7zFM.exe` per entrambi.

**Cancellare un formato nella sua colonna *Tutti gli utenti* rimuove la registrazione propria del pacchetto per computer per quel formato.** Quella colonna scrive in `HKLM\Software\Classes`, dove il pacchetto per computer tiene i ProgID e le voci *Apri con* che propone, e cancellare lì un formato (cosa che richiede il file manager avviato con *Run as administrator*, cioè come amministratore) elimina quelle chiavi per intero, per ogni account. Riparare ha ripristinato le stesse chiavi per il pacchetto per singolo utente; per questo non è stato misurato.

**Un'icona che resta vuota dopo aver cambiato qualcosa** può dipendere anche dalla cache delle icone di Explorer, che non si accorge che una DLL già messa in cache è stata sostituita; `ie4uinit.exe -show` non la svuota in modo affidabile. Chiudi Explorer, elimina `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, riavvialo.

**La disinstallazione rimuove le associazioni che riesce a raggiungere**: i ProgID `7-ZSTar.*` di chi sta disinstallando, e solo i tipi di file che puntano ancora a essi, quindi un formato passato nel frattempo a un altro programma viene lasciato stare. La disinstallazione del pacchetto per computer lascia stare anche un ProgID che apre una copia di 7-ZSTar che esiste ancora altrove, una portabile dello `.zip`, configurata con i propri **Strumenti > Opzioni > Sistema**. Il pacchetto per singolo utente non può: i suoi ProgID sono proprio quelle chiavi `HKCU` (vedi *Il pacchetto per utente* sopra), e disinstallarlo li rimuove chiunque li abbia scritti per ultimo. Lasciarli indietro farebbe puntare quei tipi a un ProgID la cui icona e il cui comando sono un eseguibile eliminato, cioè un'icona vuota e un errore al doppio clic. Le associazioni degli altri account sono fuori portata; possono rimuovere le proprie con `Setup-ShellIntegration.ps1 -RemoveAssociations` prima che il programma venga tolto. `msiexec /x ... KEEPASSOC=1` salta questo passaggio, e un aggiornamento non lo esegue mai.

**Limitazione nota: gli altri account mantengono le associazioni che hanno impostato loro.** La disinstallazione del pacchetto per computer cancella solo ciò che l'account che esegue la disinstallazione ha impostato nella propria colonna (intitolata con il nome dell'account) sotto **Strumenti > Opzioni > Sistema** nel file manager. Qualsiasi altro account che vi ha impostato associazioni le mantiene, puntate al programma rimosso, quindi facendo doppio clic su un file `.7z` Windows chiede quale programma usare. Ogni account dovrebbe cancellare le proprie **prima** della disinstallazione, con

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

che rimuove solo le voci di 7-ZSTar, oppure riassegnare i tipi dopo in Impostazioni > App > App predefinite. Farlo invece nel file manager significa fare clic su ogni cella della propria colonna che mostra 7-ZSTar finché è vuota, poi OK; non selezionare tutte le righe e premere "+", che applica un solo stato a ogni riga selezionata e quindi cancella anche i formati che appartengono a un altro programma, come il 7-Zip ufficiale.

Le associazioni impostate nella colonna **Tutti gli utenti** non vengono toccate affatto dalla pulizia della disinstallazione, e lasciano ogni account puntato al programma rimosso. Un amministratore che ne ha impostata qualcuna dovrebbe cancellare quelle celle, da un file manager avviato con *Run as administrator* (come amministratore), poi OK, prima di disinstallare; `-RemoveAssociations` non raggiunge questa colonna. Cancellarla subito prima di una disinstallazione è innocuo anche se elimina lì la registrazione propria del pacchetto (sopra), dato che la disinstallazione la rimuove comunque. Il pacchetto per singolo utente non ha il problema degli altri account, e il 7-Zip ufficiale si comporta allo stesso modo.

## Lingue

Ogni pacchetto include le traduzioni di upstream, circa 90 lingue. Sceglila in **Strumenti > Opzioni > Lingua**; l'MSI permette anche di escluderle con l'installazione *Custom*. 7-ZSTar prova a seguire la lingua di sistema al primo avvio, ma questo rilevamento rinuncia e resta in inglese quando in Windows l'impostazione "language for non-Unicode programs" (lingua per i programmi non Unicode) e l'impostazione "Formato regionale" non coincidono: scegliere una lingua a mano funziona sempre.

Le stringhe aggiunte da 7-ZSTar stesso, cioè i campi del livello e del dizionario di zstd e i nomi dei nuovi formati di archivio, non hanno una traduzione upstream e restano in inglese. L'eccezione sono i pulsanti **Dona** e **Sito web** della finestra Informazioni su 7-ZSTar: 67 delle 92 lingue hanno una traduzione per ciascuno, le altre 25 mostrano l'inglese (`Lang/UPSTREAM.md` le elenca).
Le traduzioni sono incorporate così come sono da upstream, non scritte qui: vedi [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
