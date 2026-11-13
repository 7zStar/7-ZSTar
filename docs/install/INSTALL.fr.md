<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Installer 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [简体中文](INSTALL.zh-Hans.md) · [Deutsch](INSTALL.de.md) · **Français** · [Español](INSTALL.es.md) · [Português (Brasil)](INSTALL.pt-BR.md) · [日本語](INSTALL.ja.md) · [Tiếng Việt](INSTALL.vi.md) · [Русский](INSTALL.ru.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md) · [Esperanto](INSTALL.eo.md)

*En cas de différence avec la version anglaise, c’est la version anglaise qui fait foi.*

Cette page détaille la version courte du [README](../readme/README.fr.md) : configuration requise, l’avertissement de SmartScreen, Contrôle intelligent des applications et la façon de vérifier un téléchargement, les trois packages, le menu contextuel de Windows 11, les associations de fichiers et la désinstallation.

## Configuration requise

**Windows 7 ou Windows Server 2008 R2, x64 ou x86. Sur arm64, Windows 10.**
Rien d’autre n’est nécessaire : le runtime C est lié statiquement (`-MT`), si bien que les binaires n’importent rien d’autre que les DLL de Windows lui-même — aucun package redistribuable, aucun .NET.

Cette configuration minimale est *déduite* de ce qu’exigent les packages, et elle a été testée sur Windows 7 SP1 avec les mises à jour ultérieures installées (dont PowerShell 5.1), sur Windows 10 22H2 et sur Windows 11, tous en 64 bits. Sous Windows 7 et 10, ces tests ont porté sur l’installation et la désinstallation du `.msi` x64 pour tous les utilisateurs et par utilisateur, l’assistant d’installation, le `.zip` x64, chaque codec ajouté et chaque format tar en une seule étape, le menu contextuel, les associations de fichiers et le fichier d’aide, ainsi que sur le `.msi` et le `.zip` x86 exécutés sous Windows 64 bits. Rien d’autre n’a été testé sous Windows : ni Windows 8 ou 8.1, ni Windows Server, ni Windows 32 bits, ni matériel arm64, ni Windows 7 sans ces mises à jour. Cette configuration minimale est aussi plus élevée que celle du 7-Zip upstream, dont les binaires se chargent encore sous Windows XP. Trois éléments la placent à ce niveau, et le deuxième est celui qu’aucun réglage de compilation ne peut défaire :

- Le `.msi` déclare `InstallerVersion="500"`, et Windows Installer 5.0 a été livré « with Windows Server 2008 R2 and later and Windows 7 and later » (c’est-à-dire avec Windows Server 2008 R2 et les versions ultérieures, et avec Windows 7 et les versions ultérieures) ([Microsoft][msi-versions]). Le `.zip` portable ne passe pas par Windows Installer, mais voir les deux points suivants.
- **zstd et fast-lzma2 utilisent une synchronisation qui n’existe que depuis Vista.** Tous deux forcent `_WIN32_WINNT 0x0600` dans leurs propres en-têtes et appellent directement `InitializeConditionVariable` / `SleepConditionVariableCS`, de sorte que `7z.dll` et `7za.exe` — les deux binaires dans lesquels les codecs sont compilés — importent quatre fonctions que Windows XP et Server 2003 n’ont pas. Le `7z.dll` upstream n’en importe aucune.
- La chaîne d’outils : ces binaires sont compilés avec Visual Studio 2022, dont la liste des cibles prises en charge va de Windows 7 aux versions ultérieures ; Vista et Server 2008 sont « No » ([Microsoft][vs-targeting]). La version du sous-système liée est 6.0 sur x64 et x86 et 6.2 sur arm64, et Windows sur arm64 commence de toute façon à Windows 10.

Windows Vista et Server 2008 se situent entre les deux : les binaires se chargeraient, mais la chaîne d’outils ne les prend pas en charge, le programme d’installation ne s’y exécutera pas et 7-ZSTar n’y est pas testé.

**Linux n’est pris en charge que sous forme de build en ligne de commande ; macOS n’est pas pris en charge.**
Le fork compile un `7zz` natif (le programme console `Alone2`) avec gcc, au moyen de son propre makefile, qui inclut ceux de upstream sans en modifier aucun :
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Il n’a été compilé et testé que sous Ubuntu 24.04 avec gcc 13.3 (x86-64) : la compilation ne produit aucun avertissement avec les options de upstream, le smoke test de 77 vérifications réussit, et les 25 vecteurs d’interopérabilité créés sous Windows et les 37 créés sous Linux donnent les mêmes verdicts que sous Windows. Les deux fichiers propres au fork que le portage a touchés se compilent toujours sans modification sous Windows (build x64 propre, smoke tests et relecture d’interopérabilité réussissent tous). Il n’y a pas d’interface graphique. Les autres cibles Linux de upstream (`7za`, `7zr`, `7z.so`) ne sont pas prises en charge : leurs listes d’objets gcc n’ont pas ce dont les modifications du fork apportées aux gestionnaires de upstream ont besoin, et l’on s’attend donc à ce que l’édition de liens échoue. Les autres architectures, distributions et compilateurs n’ont pas été vérifiés, et macOS n’a jamais été compilé, de sorte qu’aucun `MACOSX_DEPLOYMENT_TARGET` ne peut être indiqué. Les étapes de compilation, les tests et les limites connues se trouvent dans `build/linux/README.md` ; l’interopérabilité avec les outils Linux est décrite dans `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Packages non signés, SmartScreen et Contrôle intelligent des applications

**Les programmes d’installation et les programmes d’une version de 7-ZSTar ne sont pas signés par une autorité de certification**, et ce projet ne détient aucun certificat de signature de code. Windows ne peut donc pas savoir qui a publié le fichier, et lorsque vous exécutez le `.msi`, ou un programme du `.zip`, pour la première fois, Microsoft Defender SmartScreen peut le bloquer avec un avertissement. La documentation de Microsoft destinée aux développeurs cite « No signature » (aucune signature) parmi les cas qui affichent un avertissement intitulé « Windows a protégé votre ordinateur » (« Windows protected your PC » dans le texte de Microsoft), où l’utilisateur doit choisir « Run anyway » (« Exécuter quand même ») avant que l’application ne s’exécute ([Microsoft][smartscreen-rep]). Une stratégie d’entreprise peut supprimer entièrement ce choix ; sur un tel PC, adressez-vous à la personne qui le gère.

La seule chose d’une version qui *est* signée est le petit package qui place 7-ZSTar au premier niveau du menu contextuel de Windows 11, à l’intérieur du `.msi` pour tous les utilisateurs. Son certificat est auto-signé et généré pendant la compilation de ce seul package ; ce n’est donc pas la signature d’une autorité de certification, et il ne dit rien de qui a compilé le package ; voir [le menu contextuel de Windows 11](#le-menu-contextuel-de-windows-11) pour ce qu’il fait et la façon de le refuser.

L’avertissement ne prouve pas qu’un fichier est mauvais, et son absence ne prouverait pas qu’un fichier est sain. Ce que vous pouvez vérifier vous-même, c’est que votre copie est exactement celle publiée sur la page de la version. Chaque version comporte un fichier nommé `SHA256SUMS` : une ligne par package, avec une empreinte SHA-256 suivie du nom du fichier.

1. Téléchargez le package et `SHA256SUMS` depuis la même page de version, dans le même dossier.
2. Ouvrez PowerShell dans ce dossier et comparez. Remplacez le nom par celui du fichier que vous avez téléchargé :

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` signifie que les empreintes sont identiques. Pour les consulter vous-même, exécutez plutôt
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` et cherchez le même
   nom de fichier dans `SHA256SUMS` ; la comparaison ne tient pas compte des majuscules et des minuscules.
3. Si vous obtenez `False`, ou si le nom du fichier ne figure pas dans `SHA256SUMS`, ne l’exécutez pas : supprimez le fichier et téléchargez-le de nouveau. S’il ne correspond toujours pas, signalez-le comme décrit dans [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` ne couvre que les fichiers mis en ligne avec cette version. Compiler vous-même le même tag donne des empreintes différentes (le package du menu contextuel est signé avec un nouveau certificat à chaque compilation), et le code source est publié avec chaque version si vous préférez le compiler : voir [build/README.md](../../build/README.md).

Une fois les empreintes identiques et si vous êtes satisfait de la provenance du fichier :

- **`.msi`** : lancez-le comme d’habitude. Si SmartScreen le bloque, choisissez l’option pour l’exécuter quand même (« Run anyway » sur un Windows en anglais, « Exécuter quand même » sur un Windows en français). Il peut être nécessaire de développer d’abord la fenêtre d’avertissement : sur la machine Windows 10 testée, elle ne proposait qu’un bouton pour ne pas exécuter le fichier tant qu’on n’avait pas cliqué sur le lien situé sous son message. Le `.msi` pour tous les utilisateurs demande ensuite l’approbation d’un administrateur, comme n’importe quel programme d’installation.
- **`.zip`** : extrayez-le et lancez `7zFM.exe` ou `7z.exe` depuis le dossier. Les programmes qu’il contient ne sont pas signés non plus ; Windows peut donc afficher le même avertissement la première fois que vous lancez chacun d’eux.

SmartScreen avertit en fonction de la notoriété d’un fichier, et pas seulement des signatures ; un fichier téléchargé par peu de personnes peut le déclencher même s’il est signé. Rien ici ne change cela, et rien dans les étapes ci-dessus ne désactive SmartScreen.

### Contrôle intelligent des applications sous Windows 11

Sur certains PC sous Windows 11, une protection plus stricte appelée **Contrôle intelligent des applications** est activée. Lorsqu’elle l’est, Windows bloque les fichiers non signés, à moins que le service cloud de Microsoft ne puisse se porter garant d’eux, et une nouvelle version n’a généralement pas un tel historique ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Contrairement à l’avertissement de SmartScreen, le blocage ne propose aucune option pour exécuter quand même le fichier, et la FAQ de Microsoft indique qu’il n’existe aucun moyen de contourner Contrôle intelligent des applications pour une application donnée.

Voici ce qui s’est passé lorsque 7-ZSTar 26.05.1 a été essayé sur Windows 11 Pro 25H2 (build 26200.8037) avec Contrôle intelligent des applications activé :

- **Les programmes d’installation `.msi` ont été bloqués**, celui pour tous les utilisateurs comme celui par utilisateur. Sur un Windows en chinois traditionnel, Windows Installer a affiché « 系統禁用此安裝。請連絡系統管理員。 », et une notification de Sécurité Windows a indiqué que Contrôle intelligent des applications avait bloqué le fichier, parce que Windows ne pouvait pas savoir qui l’avait publié et qu’il ne s’agit pas d’une application connue de Windows. Il n’y avait aucune option pour continuer, et `msiexec /i ... /qn` a renvoyé l’erreur 1625. Ce message est la chaîne 1625 de Windows Installer ; sur un Windows en anglais, la même chaîne se lit « The system administrator has set policies to prevent this installation. » (lue dans les ressources anglaises de Windows Installer, et non vue à l’écran).
- **Un programme du `.zip` s’est exécuté.** `7zFM.exe`, extrait du `.zip` portable, s’est lancé normalement lors du même test. Que Windows laisse s’exécuter un programme non signé relève de son propre jugement sur ce fichier ; il peut donc en aller autrement sur votre PC.
- Juste après l’activation de Contrôle intelligent des applications, le `.msi` s’est installé pendant quelques minutes avant de commencer à être bloqué. La cause n’a pas été trouvée ; une réussite juste après l’activation ne signifie donc pas que le programme d’installation est autorisé.

Ainsi, sur un PC où Contrôle intelligent des applications est activé, **les programmes d’installation ne peuvent pas être installés**, et vérifier `SHA256SUMS` n’y change rien. Ce qui y change quelque chose, c’est de désactiver Contrôle intelligent des applications dans les Paramètres de Contrôle intelligent des applications de l’application Sécurité Windows (sur le Windows en chinois traditionnel testé : Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). Lors du test, le choix de l’option Désactivé a pris effet immédiatement, sans redémarrage, et les programmes d’installation se sont ensuite installés. C’est un réglage qui concerne tout le PC et rien ici ne vous demande de le modifier : cela vous appartient, ou appartient à votre administrateur sur un PC géré.

Il est aussi utile de savoir d’abord s’il peut être réactivé. La FAQ de Microsoft indique que les mises à jour récentes de Windows permettent de réactiver Contrôle intelligent des applications sans réinstallation propre de Windows ; sur une version qui ne les a pas, le désactiver peut donc être définitif. Sur le build testé ici, l’option pour l’activer était encore proposée après l’avoir désactivé ; c’est un résultat de test, pas une promesse pour votre version.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Installation

Trois packages, tous créés par `installer\Build-Package.ps1` (celui par utilisateur avec `-PerUser`) :

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| S’installe pour | tous les comptes | le compte qui installe | - |
| Menu contextuel de l’Explorateur de fichiers | oui | oui, menu classique uniquement ([ci-dessous](#le-package-par-utilisateur)) | non |
| Entrée du Menu Démarrer | oui | oui | non |
| Nécessite un administrateur | oui | non | non |
| Désinstallation | *Applications installées* dans Paramètres | *Applications installées* dans Paramètres | supprimer le dossier |

*Applications installées* est le nom sous Windows 11. Windows 10 appelle la même page *Applications et fonctionnalités*, et sous Windows 7 il s’agit de *Programmes et fonctionnalités* dans le Panneau de configuration.

Utilisez les packages qui correspondent à Windows lui-même : x86 sous Windows 32 bits, x64 sous Windows 64 bits, arm64 sous Windows on Arm (les packages arm64 sont créés mais n’ont jamais été exécutés). L’extension du shell x86 est en 32 bits et l’Explorateur de fichiers 64 bits ne peut pas la charger ; sous Windows 64 bits, le `-user.msi` x86 n’a donc aucun menu contextuel, et le `.msi` x86 n’en a un que sous Windows 11 et seulement pour les comptes qui ont enregistré son package Windows 11 (celui qui a installé, ou un compte qui a exécuté `-Register`, voir ci-dessous).

Le MSI s’installe dans `Program Files\7-ZSTar`, toujours : contrairement au package par utilisateur, il n’offre aucun choix de dossier et ignore `INSTALLFOLDER` sur la ligne de commande, car ce dossier contient un script que le programme d’installation exécute en tant que SYSTEM et une DLL que l’Explorateur de fichiers de chaque utilisateur charge, et un dossier créé ailleurs (sous `C:\`, par exemple) est modifiable par tous les utilisateurs. Il enregistre son propre CLSID d’extension du shell et sa propre ruche de registre `Software\7-ZSTar`, et nomme `7-ZSTar` chaque clé du menu contextuel : il n’entre donc pas en collision avec celles du 7-Zip officiel et ne les supprime pas. Voir [installer/GUIDS.md](../../installer/GUIDS.md).

Il lance un assistant d’installation normal (welcome, licence, setup type, optional feature tree, finish : accueil, licence, type d’installation, arborescence des fonctionnalités facultatives, fin) et l’installation silencieuse fonctionne toujours à l’identique (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), car msiexec saute toute la séquence d’interface en mode silencieux. L’assistant n’existe qu’en anglais, y compris sur un Windows réglé sur une autre langue (constaté sous Windows 10 en chinois traditionnel ; le `.msi` est compilé sans autre langue), et sur sa page de fin, *Launch 7-ZSTar File Manager* est coché par défaut.

### Le menu contextuel de Windows 11

Sous Windows 11, l’entrée se trouve dans le menu de premier niveau, et non enfouie sous *Afficher d’autres options* où se trouvent encore le 7-Zip officiel et WinRAR. Windows 11 n’y liste une extension du shell que si elle est fournie avec une identité de package ; le MSI livre donc, à côté du programme, un petit package MSIX réduit à l’identité et l’enregistre pendant l’installation. L’enregistrement classique est conservé aussi. C’est lui qui place l’entrée dans le menu contextuel sous Windows 10 et Windows 7, dont le menu n’a qu’un seul niveau et pas de *Afficher d’autres options*, et c’est lui qui la maintient pour quiconque a rétabli l’ancien menu contextuel.

Ce package est signé avec un **certificat auto-signé**, et le programme d’installation le place dans `LocalMachine\TrustedPeople` : Windows ne déploie pas un package dont la signature ne remonte pas à quelque chose de fiable. La désinstallation retire le certificat en même temps que le package. Sous Windows 10 et Windows 7, le programme d’installation ne fait ni l’un ni l’autre : il n’ajoute aucun certificat et n’enregistre aucun package, et l’enregistrement classique seul fournit le menu.

Si vous préférez ne pas faire confiance à un certificat auto-signé, refusez seulement cette partie et gardez tout le reste :

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Vous n’obtenez alors que le menu classique ; sous Windows 11, l’entrée 7-ZSTar se trouve donc dans le menu contextuel sous *Afficher d’autres options*. Pour activer plus tard l’entrée de premier niveau, ou pour l’annuler après une installation normale :

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Faire confiance à ce certificat signifie que Windows acceptera aussi sans avertissement **tout autre** package signé avec la même clé. Il n’est utilisé que pour ce seul package, et la désinstallation le retire, mais c’est à cela que vous consentez : `SPARSE=0` ci-dessus est le moyen de le refuser.

L’enregistrement du package se fait par utilisateur, et le programme d’installation ne l’exécute que pour la personne qui a installé. Deux conséquences :

- Un deuxième compte sur la même machine n’a que le menu classique, jusqu’à ce qu’il exécute ce même script avec `-Register`.
- La désinstallation ne retire l’enregistrement que pour la personne qui désinstalle. Si quelqu’un d’autre l’a enregistré, son enregistrement survit à la désinstallation et pointe vers un dossier qui n’existe plus ; ce compte le supprime avec `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Limitation connue : le menu de premier niveau n’est enregistré que lorsque l’installation s’exécute dans une session interactive ouverte.** Installer le `.msi` pour tous les utilisateurs depuis une session distante ou non interactive — via SSH, ou un déploiement silencieux depuis un outil de gestion — signale tout de même une réussite, mais le package Windows 11 n’est pas enregistré, et seul le menu classique sous *Afficher d’autres options* apparaît. Lors du test, `msiexec /i ... /qn` depuis une session SSH (session 0) s’est terminé avec 0 alors que `Setup-ShellIntegration.ps1` signalait `registration failed: 0x80070005` (« Accès refusé. ») ; le même `.msi` installé depuis la session console d’un administrateur s’est enregistré normalement.

`-Status` affiche ce qui est en place et ce qui ne l’est pas.

### Le package par utilisateur

`7-ZSTar-<version>-<arch>-user.msi` s’installe pour le compte actuel seulement, dans `%LOCALAPPDATA%\Programs\7-ZSTar`, sans invite du Contrôle de compte d’utilisateur. Tout ce qu’il enregistre va sous `HKCU` ; le package n’écrit rien dans `HKLM` (hormis la comptabilité interne de Windows Installer). Voici ce qu’il ne fait pas comme le package par machine :

- **Pas de menu de premier niveau sous Windows 11.** Sous Windows 11, 7-ZSTar se trouve dans le menu contextuel sous *Afficher d’autres options*. L’entrée de premier niveau exige que le certificat auto-signé soit approuvé à l’échelle de la machine, ce qui demande un administrateur : mesuré sous Windows 11, un certificat dans `CurrentUser\TrustedPeople` ne suffit pas pour que Windows déploie le package. Le package par utilisateur l’omet donc.
- **Un seul des deux par machine.** Chaque package refuse de s’installer tant que l’autre est installé ; désinstallez l’un avant d’installer l’autre. Le package par machine ne voit que la copie par utilisateur du compte qui l’exécute ; l’installation par utilisateur d’un autre compte n’est donc pas détectée.
- **Le menu peut être masqué par la Stratégie de groupe.** Là où `EnforceShellExtensionSecurity` est défini, l’Explorateur de fichiers ne charge que les extensions du shell listées sous la clé *Approved* à l’échelle de la machine, qu’une installation par utilisateur ne peut pas écrire ; le menu contextuel n’apparaît donc pas. Utilisez-y le package par machine.
- **Effacer un format dans Outils > Options > Système supprime aussi ce que 7-ZSTar propose pour lui.** Lorsque vous y effacez un format (cliquez sur sa cellule jusqu’à ce qu’elle soit vide, puis sur OK), le gestionnaire de fichiers supprime en entier les clés `HKCU\Software\Classes\.<ext>` et `7-ZSTar.<ext>` — et pour une installation par utilisateur, ces clés contiennent aussi ce que le package a enregistré pour Paramètres > Applications > Applications par défaut et pour la liste *Ouvrir avec*. 7-ZSTar disparaît alors de *Ouvrir avec* pour ce format, et Applications par défaut affiche une entrée vide pour lui. Réparer l’installation le rétablit (exécutez de nouveau le `.msi` et choisissez *Repair* (réparer)). Mieux : attribuez les types de fichiers dans Applications par défaut plutôt que dans le gestionnaire de fichiers. Le package par machine a la même faiblesse à un endroit, décrit plus bas dans les associations de fichiers.

### Associations de fichiers et effet de la désinstallation

**Définissez-les dans Paramètres > Applications > Applications par défaut.** Sous Windows 11, tapez 7-ZSTar à cet endroit et chaque format qu’il peut ouvrir est listé pour être attribué. Sous Windows 10, 7-ZSTar est listé sous *Set defaults by app* (définir les valeurs par défaut par application) sur cette page, où *Manage* (gérer) affiche ses formats. Windows 7 n’a pas d’application Paramètres : 7-ZSTar est listé dans Panneau de configuration > Programmes par défaut > *Configurer les programmes par défaut*, ce que désigne *Applications par défaut* dans ce guide pour cette version. L’attribution des formats depuis ces deux pages n’a pas été testée. Le programme d’installation enregistre 7-ZSTar comme application de Programmes par défaut — un ProgID par format avec son icône et sa commande d’ouverture, une entrée dans la liste *Ouvrir avec* de chaque extension, et le bloc Capabilities que Windows lit — mais il ne revendique volontairement aucun type de fichier : quel programme ouvre vos archives est votre décision, et c’est ce qui empêche 7-ZSTar et le 7-Zip officiel de se gêner l’un l’autre. Windows peut tout de même diriger de lui-même un format vers 7-ZSTar lorsqu’aucun autre programme ne se propose pour l’ouvrir : sur les machines Windows 10 et Windows 7 testées, où rien d’autre n’avait enregistré `.7z`, un fichier `.7z` affichait l’icône de 7-ZSTar et s’ouvrait avec lui par double-clic, sans que Windows demande quel programme utiliser.

**Outils > Options > Système dans le gestionnaire de fichiers ne fonctionne en grande partie pas sous Windows 11**, et c’est une règle de Windows plutôt qu’un bogue ici. Il écrit un ProgID `7-ZSTar.<ext>` dans `HKCU\Software\Classes`, et pour toute extension que la machine connaît déjà — c’est le cas de tous les formats d’archive — Windows 11 l’ignore : `AssocQueryString` répond `Unknown` et l’Explorateur de fichiers dessine l’icône générique vide. Ce qu’il respecte à la place, c’est une clé `UserChoice` marquée d’un hash que seul Windows peut calculer, et c’est pourquoi l’interface de Paramètres est la seule voie à cet endroit. Aucune application ne peut en écrire une : ni 7-ZSTar, ni 7-Zip, ni aucun programme d’installation. Windows 10 et Windows 7 se sont comportés différemment lors des tests : une fois `.7z` et `.zst` définis dans le gestionnaire de fichiers, sans qu’aucun autre programme soit choisi pour eux, `AssocQueryString` a renvoyé `7zFM.exe` pour les deux.

**Effacer un format dans sa colonne *Tous les utilisateurs* supprime l’enregistrement propre du package par machine pour ce format.** Cette colonne écrit dans `HKLM\Software\Classes`, où le package par machine conserve les ProgID et les entrées *Ouvrir avec* qu’il propose, et y effacer un format (ce qui demande le gestionnaire de fichiers lancé avec *Exécuter en tant qu’administrateur*) supprime ces clés en entier — pour chaque compte. Réparer a rétabli les mêmes clés pour le package par utilisateur ; pour celui-ci, cela n’a pas été mesuré.

**Une icône qui reste vide après un changement quelconque** peut aussi venir du cache d’icônes de l’Explorateur de fichiers, qui ne remarque pas qu’une DLL déjà mise en cache a été remplacée ; `ie4uinit.exe -show` ne le vide pas de façon fiable. Fermez l’Explorateur de fichiers, supprimez `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, puis relancez-le.

**La désinstallation supprime les associations qu’elle peut atteindre** — les ProgID `7-ZSTar.*` appartenant à la personne qui désinstalle, et seulement les types de fichiers qui pointent encore vers eux ; un format confié entre-temps à un autre programme est donc laissé tel quel. La désinstallation du package par machine laisse aussi de côté un ProgID qui ouvre une copie de 7-ZSTar qui existe toujours ailleurs — une copie portable issue du `.zip`, configurée avec ses propres **Outils > Options > Système**. Le package par utilisateur ne le peut pas : ses ProgID sont ces mêmes clés `HKCU` (voir *Le package par utilisateur* ci-dessus), et le désinstaller les supprime quel que soit celui qui les a écrits en dernier. Les laisser en place ferait pointer ces types vers un ProgID dont l’icône et la commande sont un exécutable supprimé, ce qui donne une icône vide et une erreur au double-clic. Les associations des autres comptes sont hors d’atteinte ; ils peuvent supprimer les leurs avec `Setup-ShellIntegration.ps1 -RemoveAssociations` avant que le programme ne soit retiré. `msiexec /x ... KEEPASSOC=1` saute cette étape, et une mise à niveau ne l’effectue jamais.

**Limitation connue : les autres comptes conservent les associations qu’ils ont définies eux-mêmes.** La désinstallation du package par machine n’efface que ce que le compte qui exécute la désinstallation a défini dans sa propre colonne (intitulée du nom du compte) sous **Outils > Options > Système** dans le gestionnaire de fichiers. Tout autre compte qui y a défini des associations les conserve, pointant vers le programme supprimé ; un double-clic sur un fichier `.7z` fait alors demander à Windows quel programme utiliser. Chaque compte devrait effacer les siennes **avant** la désinstallation, avec

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

qui ne supprime que les entrées de 7-ZSTar, ou bien attribuer de nouveau les types ensuite dans Paramètres > Applications > Applications par défaut. Le faire plutôt dans le gestionnaire de fichiers revient à cliquer sur chaque cellule de sa propre colonne qui affiche 7-ZSTar jusqu’à ce qu’elle soit vide, puis sur OK ; ne sélectionnez pas toutes les lignes pour appuyer sur « + », ce qui applique un seul état à chaque ligne sélectionnée et efface donc aussi les formats qui appartiennent à un autre programme, comme le 7-Zip officiel.

Les associations définies dans la colonne **Tous les utilisateurs** ne sont pas touchées du tout par le nettoyage de la désinstallation, et laissent chaque compte pointer vers le programme supprimé. Un administrateur qui en a défini devrait effacer ces cellules, depuis un gestionnaire de fichiers lancé avec *Exécuter en tant qu’administrateur*, puis cliquer sur OK, avant de désinstaller ; `-RemoveAssociations` n’atteint pas cette colonne. L’effacer juste avant une désinstallation est sans danger, même si cela supprime à cet endroit l’enregistrement propre du package (voir plus haut), puisque la désinstallation le supprime de toute façon. Le package par utilisateur n’a pas le problème des autres comptes, et le 7-Zip officiel se comporte de la même façon.

## Langues

Chaque package embarque les traductions de upstream, plus de 90 langues. Choisissez-en une dans **Outils > Options > Langue** ; le MSI permet aussi de les exclure avec l’installation *Custom* (personnalisée). 7-ZSTar essaie de suivre la langue du système au premier lancement, mais cette détection abandonne et reste en anglais lorsque, dans Windows, le paramètre « Langue pour les programmes non Unicode » et le paramètre « Format régional » ne concordent pas : choisir une langue à la main fonctionne toujours.

Les chaînes ajoutées par 7-ZSTar lui-même — les champs du niveau et du dictionnaire de zstd, les noms des nouveaux formats d’archive — n’ont pas de traduction upstream et restent en anglais. L’exception est celle des boutons **Don** et **Site web** de la boîte de dialogue À propos de 7-ZSTar : 67 des 92 langues ont une traduction pour chacun, les 25 autres affichent l’anglais (`Lang/UPSTREAM.md` les liste).
Les traductions sont intégrées telles quelles depuis upstream, et non rédigées ici : voir [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
