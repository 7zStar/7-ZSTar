<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · **Français** · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*En cas de différence avec la version anglaise, c’est la version anglaise qui fait foi.*

**Un fork de 7-Zip plus agréable pour les utilisateurs de Windows 11 d’aujourd’hui : un menu contextuel au premier niveau, la compression zstd et tar.zst en une seule passe.**

[Télécharger](https://github.com/7zStar/7-ZSTar/releases/latest) · [Site web](https://www.7zstar.com) · [Journal des modifications](../../CHANGELOG.md)

## Pourquoi 7-ZSTar

- **Fini « Afficher d’autres options ».** Sous Windows 11, 7-ZSTar se trouve directement au premier niveau du menu contextuel.
- **tar.zst en une seule étape.** Compressez un dossier en .tar.zst, ou extrayez-en un, en une seule étape, sans qu’aucun .tar ne reste sur le disque. Le 7-Zip officiel ne sait pas créer de .tar.zst, et en extrait un en deux étapes, en passant par un .tar.
- **Environ 10× plus rapide que 7z.** Sur de vrais dossiers de projet, tar.zst a compressé 10 à 18 fois plus vite.

## Vitesse

| Dossier | Fichiers | Taille brute | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (gros binaires) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst est ressorti 15 à 23 % plus petit que zip, sans être plus lent. 7z produit toujours les plus petits fichiers (tar.zst était 15 à 27 % plus gros), mais il a pris beaucoup plus de temps. L’extraction a pris à peu près le même temps avec les trois.

Réglages par défaut pour les trois ; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, SSD NVMe, médiane de 3 exécutions, 2026-11.

## Formats

- **Compression en une étape :** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Extraction en une étape :** tous ceux-ci, plus tar.lzma et tar.Z
- **Codecs ajoutés :** zstd, brotli, lz4, lz5 et lizard (seuls ou à l’intérieur d’un .7z), plus fast-lzma2, un encodeur LZMA2 alternatif
- Tous les formats pris en charge par le 7-Zip officiel fonctionnent toujours.

## Télécharger

La plupart des gens veulent le `.msi` x64 pour tous les utilisateurs, disponible sur la page des [Versions](https://github.com/7zStar/7-ZSTar/releases/latest).

| | Tous les utilisateurs `.msi` | Vous seul `-user.msi` | Portable `.zip` |
|---|---|---|---|
| Droits d’administrateur requis | Oui | Non | Non |
| Menu contextuel | 1er niveau sous Windows 11 | Menu classique (sous « Afficher d’autres options » sous Windows 11) | Aucun |
| Entrée dans le Menu Démarrer | Oui | Oui | Non |

Chacun existe aussi en x86 et en arm64 ; choisissez celui qui correspond à votre Windows. Sous Windows 64 bits, les packages x86 peuvent n’avoir aucun menu contextuel, et les builds arm64 n’ont pas encore été essayés sur du matériel réel. 7-ZSTar s’installe à côté du 7-Zip officiel, sans l’affecter.

**Windows peut afficher un avertissement la première fois.** Les fichiers ne sont pas signés (signature de code) ; SmartScreen peut donc les bloquer (« Windows a protégé votre ordinateur » ; il peut falloir développer l’avertissement pour voir *Exécuter quand même*), et sous Windows 11 avec Contrôle intelligent des applications activé, le `.msi` est purement et simplement bloqué. Chaque version comprend un fichier `SHA256SUMS` qui permet de vérifier votre téléchargement. [Le guide d’installation](../install/INSTALL.fr.md#packages-non-signés-smartscreen-et-contrôle-intelligent-des-applications) explique comment faire, et quoi faire à propos de Contrôle intelligent des applications.

**À propos du menu au premier niveau :** sous Windows 11, le `.msi` pour tous les utilisateurs ajoute un petit package signé avec un certificat auto-signé et approuve ce certificat ; c’est ce que Windows exige pour le premier niveau. La désinstallation retire les deux. Si vous préférez éviter cela, installez avec `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Le package est enregistré pour le compte qui exécute le programme d’installation ; les autres comptes l’enregistrent séparément.

Les associations de fichiers, la désinstallation et le package par utilisateur sont décrits dans [le guide d’installation](../install/INSTALL.fr.md).

## Ligne de commande

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Dans PowerShell, mettez le commutateur entre guillemets : `7z a "-ttar.zst" backup.tar.zst docs`. Sans guillemets, PowerShell le coupe en deux et vous obtenez un fichier nommé `.zst`. Invite de commandes (cmd) n’a pas besoin de guillemets.

## À savoir

- **Décocher « Intégrer 7-ZSTar au menu contextuel »** (gestionnaire de fichiers, **Outils > Options > 7-ZSTar**) supprime l’entrée du menu contextuel, comme dans le 7-Zip officiel. Avec le package pour tous les utilisateurs, on la rétablit en lançant le gestionnaire de fichiers avec « Exécuter en tant qu’administrateur ». Avec le package par utilisateur, c’est impossible (« Accès refusé. ») ; exécutez de nouveau le `.msi` et choisissez *Repair* (réparer).
- **Les installations silencieuses ou à distance sous Windows 11** (par SSH, ou depuis un outil de déploiement) réussissent, mais l’entrée du premier niveau n’est pas enregistrée ; 7-ZSTar n’apparaît donc que sous « Afficher d’autres options ». [Plus de détails dans le guide d’installation](../install/INSTALL.fr.md#le-menu-contextuel-de-windows-11).
- **Extraire du tar.br, tar.lz4, tar.lz5, tar.liz ou tar.Z** reste une seule étape pour vous, mais passe par un fichier temporaire qui est supprimé ensuite.

## Configuration requise

Windows 7 / Server 2008 R2 ou version ultérieure (x64, x86), ou Windows 10 ou version ultérieure sur arm64. Rien d’autre à installer. Testé sur Windows 7 SP1 64 bits (avec les mises à jour ultérieures installées), Windows 10 et Windows 11 ; [ce qui a été testé](../install/INSTALL.fr.md#configuration-requise). Sous Linux, il existe un build en ligne de commande à compiler soi-même ; macOS n’est pas pris en charge.

## Documentation

**Aide > Contenu** et F1 ouvrent `7-zip.chm`, le fichier d’aide du 7-Zip officiel. Il dit « 7-Zip » partout et ne couvre pas ce qu’ajoute 7-ZSTar ; cette page et le [journal des modifications](../../CHANGELOG.md) le font. Si le fichier d’aide est absent, ces mêmes entrées ouvrent cette section en ligne.

Pour compiler 7-ZSTar vous-même, voir [build/README.md](../../build/README.md) ; avant de fusionner une nouvelle version de upstream, lisez [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Faire un don

7-ZSTar est gratuit, que vous donniez ou non. S’il vous a fait gagner du temps et que vous souhaitez dire merci, vous pouvez envoyer de la cryptomonnaie à l’adresse ci-dessous. Les sommes reçues me reviennent, à moi, DraftingDreamer, pour mes propres frais de développement ; elles ne donnent droit ni à des fonctionnalités, ni à de l’aide, ni à la moindre promesse sur la suite.

Tout token sur Ethereum ou Polygon est le bienvenu : ETH, POL, USDT, USDC ou autre. L’adresse est la même sur les deux réseaux.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="QR code de l’adresse de don">

- Seuls les transferts sur Ethereum (ERC20) et sur Polygon sont acceptés. Si les deux sont possibles pour vous, préférez Polygon : ses frais sont en général plus bas.
- C’est la seule adresse officielle, et je ne vous demanderai jamais d’envoyer à une autre.
- Les transferts sur la blockchain sont irréversibles : il n’y a donc aucun remboursement possible.

Une étoile sur GitHub ou une recommandation à un ami, c’est aussi un coup de pouce.

## Licence

LGPL v3, voir [LICENSE](../../LICENSE). Certaines parties sont soumises à d’autres conditions : la décompression RAR est soumise à la restriction unRAR ; un build avec prise en charge de RAR n’est donc pas purement sous LGPL v3. La liste complète figure dans [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), et les mentions de copyright dans [NOTICE](../../NOTICE).

Merci à toutes celles et tous ceux qui ont consacré leur temps à 7-Zip, aux algorithmes de compression et au logiciel libre en général. Sans vous, 7-ZSTar n’existerait pas.
