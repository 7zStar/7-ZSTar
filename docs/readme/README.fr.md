<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · **Français** · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Esperanto](README.eo.md)

**Un fork de 7-Zip mieux adapté à Windows 11 : menu contextuel au premier niveau, compression zstd et tar.zst en une seule passe.**

[Télécharger](https://github.com/7zStar/7-ZSTar/releases/latest) · [Site web](https://www.7zstar.com/fr/) · [Journal des modifications](../../CHANGELOG.md)

## Pourquoi 7-ZSTar

- **Sans détour par « Afficher d’autres options ».** Avec le MSI pour tous les utilisateurs, 7-ZSTar figure dès le premier niveau du menu contextuel de Windows 11.
- **Une seule passe. Pas de .tar sur le disque.** Compresser en tar.zst et extraire un tar.zst se font chacun en une seule étape, sans qu’aucun .tar soit écrit dans un sens ni dans l’autre. Le 7-Zip officiel ne sait pas créer de .tar.zst et en extrait un en deux étapes, en passant par un .tar.
- **10× plus rapide que 7z.** Sur de vrais dossiers de projet, tar.zst a compressé 10 à 18 fois plus vite que 7z.

## Vitesse

| Dossier | Fichiers | Taille brute | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13 371 | 207 Mo | 4,1 s / 76,7 Mo | 38,4 s / 51,8 Mo | **3,8 s** / 59,7 Mo |
| Python `.venv` | 9 795 | 346 Mo | 6,6 s / 107,8 Mo | 54,8 s / 65,7 Mo | **3,6 s** / 83,4 Mo |
| Python `.venv` (gros binaires) | 11 654 | 671 Mo | 25,5 s / 249,5 Mo | 100,8 s / 167,2 Mo | **5,6 s** / 210,9 Mo |

tar.zst est ressorti 15 à 23 % plus petit que zip, sans être plus lent. Il est en revanche 15 à 27 % plus gros que 7z : si la taille minimale prime, 7z reste le meilleur choix. Ces chiffres portent sur la compression ; à l’extraction, les trois ont pris à peu près le même temps.

zip, 7z et tar.zst avec les réglages par défaut. 7-ZSTar 26.05.1 x64 (7z.exe), une seule machine (Intel Core Ultra 7 155H, SSD NVMe), trois vrais dossiers de projet, médiane de 3 exécutions, 2026-11.

## Formats

- **Compression en une étape (8) :** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extraction en une étape (10) :** ces 8, plus tar.lzma et tar.Z
- **Codecs ajoutés :** zstd, brotli, lz4, lz5 et lizard, chacun comme format autonome et comme méthode à l’intérieur de .7z, plus fast-lzma2 comme encodeur LZMA2 alternatif.
- Tous les formats que 7-Zip prend déjà en charge sont toujours là.

Pour tar.br, tar.lz4, tar.lz5, tar.liz et tar.Z, l’extraction reste une seule étape de votre côté, mais 7-ZSTar décode d’abord vers un fichier intermédiaire, qu’il supprime ensuite.

## Ligne de commande

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Dans PowerShell, mettez le commutateur de format entre guillemets, comme dans `7z a "-ttar.zst" backup.tar.zst docs`. Sans eux, PowerShell coupe `-ttar.zst` en deux et 7z crée un fichier nommé `.zst`. L’Invite de commandes (cmd) n’a pas besoin de guillemets.

## Téléchargement et installation

| | Tous les utilisateurs `.msi` | Vous seul `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Installé pour | Tous les comptes du PC | Le compte actuel | Aucune installation requise |
| Droits d’administrateur requis | Oui | Non | Non |
| Menu contextuel | Windows 11 : premier niveau | Sous « Afficher d’autres options » | Aucun |
| Entrée du menu Démarrer | Oui | Oui | Non |

Chacun existe en x64, x86 et arm64 ; choisissez celui qui correspond à votre Windows : sous Windows 64 bits, les paquets x86 peuvent n’avoir aucun menu contextuel. Les versions arm64 n’ont pas encore été exécutées sur du matériel réel. 7-ZSTar s’installe à côté du 7-Zip officiel, sans que l’un n’affecte l’autre.

**Windows peut afficher un avertissement pour ces téléchargements.** Les programmes d’installation et les programmes ne sont pas signés par une autorité de certification ; Microsoft Defender SmartScreen peut donc les bloquer avec un avertissement au premier lancement, et sur un PC Windows 11 où Smart App Control est activé, les installateurs `.msi` sont bloqués d’emblée, sans aucune option pour continuer. Cela ne signifie pas que le fichier est mauvais : chaque release est publiée avec un fichier `SHA256SUMS`, qui permet de vérifier que votre téléchargement correspond à ce qui a été publié. La façon de vérifier, ce que Smart App Control signifie pour vous et comment continuer une fois la vérification concluante sont expliqués dans [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**À propos du menu au premier niveau :** Windows 11 n’admet au premier niveau que les programmes dotés d’une identité de package. Le MSI pour tous les utilisateurs installe donc un petit package MSIX signé avec un certificat auto-signé, et approuve ce certificat. La désinstallation retire les deux. Si vous préférez ne pas l’approuver, installez avec `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0` : le menu reste alors sous « Afficher d’autres options ». Le package n’est enregistré que pour le compte qui exécute le programme d’installation ; les autres comptes doivent l’enregistrer séparément.

Tous les détails, y compris les associations de fichiers et la désinstallation, se trouvent dans [docs/INSTALL.md](../INSTALL.md) (pour l’instant en anglais seulement).

## Limitations connues

- **Décocher la case d’intégration au shell supprime l’enregistrement du menu contextuel.** Dans le gestionnaire de fichiers (`7zFM`), **Outils > Options > 7-ZSTar** contient une case « Intégrer 7-ZSTar au menu contextuel ». Comme dans le 7-Zip officiel, la décocher supprime l’enregistrement de l’extension shell (sa clé `CLSID`) créé par le programme d’installation, et l’entrée 7-ZSTar disparaît du menu contextuel. Avec le MSI pour tous les utilisateurs, vous pouvez la recocher si le gestionnaire de fichiers s’exécute en tant qu’administrateur. Avec le MSI par utilisateur, c’est impossible : la recocher affiche « Accès refusé » et l’entrée reste absente. Pour la récupérer, relancez le `.msi` d’origine et choisissez *Réparer*.
- **Le menu de premier niveau n’est enregistré que si l’installation s’exécute dans une session interactive ouverte par un utilisateur.** Installer le `.msi` pour tous les utilisateurs depuis une session distante ou non interactive (via SSH, ou lors d’un déploiement silencieux depuis un outil d’administration) signale toujours un succès, mais le paquet Windows 11 n’est pas enregistré : seul le menu classique sous « Afficher d’autres options » apparaît. Les détails sont dans [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu).

## Configuration requise

Windows 7 ou Windows Server 2008 R2 et ultérieurs (x64, x86) ; Windows 10 et ultérieurs sur arm64. Rien d’autre à installer. Ce seuil découle de ce qu’exigent les paquets ; les versions antérieures à Windows 11 n’ont pas été testées. Sous Linux, il existe une version en ligne de commande à compiler vous-même ; macOS n’est pas pris en charge.

## À propos de ce projet

7-ZSTar est un fork de 7-Zip mieux adapté à Windows 11. Le cœur de 7-Zip est excellent, mais certains points n’ont pas suivi la façon dont on travaille aujourd’hui : Windows 11 le range sous « Afficher d’autres options », et il ne sait pas non plus compresser en zstd. 7-ZSTar comble ces lacunes et laisse tout le reste comme vous le connaissez.

## Documentation

Chaque paquet contient `7-zip.chm`, le fichier d’aide du 7-Zip officiel, non modifié : **Aide > Contenu** et F1 l’ouvrent. Il parle de « 7-Zip » d’un bout à l’autre et ne couvre pas ce qu’ajoute 7-ZSTar ; pour cela, voyez cette page et [CHANGELOG.md](../../CHANGELOG.md).

Si le fichier d’aide n’est pas à côté de l’exécutable, ces mêmes entrées ouvrent à la place cette section en ligne (en anglais).

## Compiler depuis les sources

Voir [build/README.md](../../build/README.md). En bref : VS2022 Build Tools (MSVC v143), puis `pwsh build\Build.ps1`. Avant d’intégrer une nouvelle version amont, lisez [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Faire un don

7-ZSTar est gratuit, que vous donniez ou non. S’il vous a fait gagner du temps et que vous souhaitez dire merci, vous pouvez envoyer de la cryptomonnaie à l’adresse ci-dessous. Les sommes reçues me reviennent, à moi, DraftingDreamer, pour mes propres frais de développement ; elles ne donnent droit ni à des fonctionnalités, ni à de l’aide, ni à la moindre promesse sur la suite.

Tout token sur Ethereum ou Polygon est le bienvenu : ETH, POL, USDT, USDC ou autre. L’adresse est la même sur les deux réseaux.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR code de l’adresse de don">

- Seuls les transferts sur Ethereum (ERC20) et sur Polygon sont acceptés. Si les deux sont possibles pour vous, préférez Polygon : ses frais sont en général plus bas.
- C’est la seule adresse officielle, et je ne vous demanderai jamais d’envoyer à une autre.
- Les transferts sur la blockchain sont irréversibles : il n’y a donc aucun remboursement possible.

Une étoile sur GitHub ou une recommandation à un ami, c’est aussi un coup de pouce.

## Licence

LGPL v3, voir [LICENSE](../../LICENSE). Certaines parties relèvent d’autres conditions : la décompression RAR, par exemple, porte la restriction unRAR ; une version avec prise en charge de RAR n’est donc pas purement LGPL v3. La liste complète figure dans [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), et les mentions de droits d’auteur de chaque composant dans [NOTICE](../../NOTICE).

## Remerciements

7-ZSTar repose sur le travail de nombreuses personnes. Merci à toutes les personnes qui ont donné de leur temps à 7-Zip, aux algorithmes de compression et à l’open source en général. Sans vous, ce logiciel n’existerait pas.
