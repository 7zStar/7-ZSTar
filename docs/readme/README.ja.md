<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · **日本語** · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*英語版と内容が異なる場合は、英語版が優先されます。*

**Windows 11ユーザーにとってもっと使いやすい7-Zipのフォーク。右クリックメニューの第1階層、zstd圧縮、一度で作れるtar.zst。**

[ダウンロード](https://github.com/7zStar/7-ZSTar/releases/latest) · [ウェブサイト](https://www.7zstar.com) · [変更履歴](../../CHANGELOG.md)

## 7-ZSTarを選ぶ理由

- **「その他のオプションを確認」は、もう不要です。** Windows 11では、7-ZSTarは右クリックメニューの第1階層に並びます。
- **tar.zstが一度で完了。** フォルダーを.tar.zstに圧縮するのも、展開するのも1ステップで済み、ディスクに.tarは残りません。公式の7-Zipは.tar.zstを作成できず、展開も.tarを経由する2段階です。
- **7zの10倍ほど速い。** 実際のプロジェクトフォルダーでは、tar.zstの圧縮は10〜18倍速く終わりました。

## 速度

| フォルダー | ファイル数 | 元のサイズ | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1秒 / 76.7 MB | 38.4秒 / 51.8 MB | **3.8秒** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6秒 / 107.8 MB | 54.8秒 / 65.7 MB | **3.6秒** / 83.4 MB |
| Python `.venv`（大きなバイナリを含む） | 11,654 | 671 MB | 25.5秒 / 249.5 MB | 100.8秒 / 167.2 MB | **5.6秒** / 210.9 MB |

tar.zstはzipより15〜23%小さく、速度も劣りませんでした。最も小さなファイルを作れるのは今も7zですが（tar.zstは15〜27%大きい）、時間は大幅にかかりました。展開にかかった時間は、3つともほぼ同じでした。

3つとも既定の設定。7-ZSTar 26.05.1 x64、Intel Core Ultra 7 155H、NVMe SSD、3回の中央値、2026-11。

## 対応形式

- **一度で圧縮：** tar.zst、tar.br、tar.lz4、tar.lz5、tar.liz、tar.gz、tar.bz2、tar.xz
- **一度で展開：** 上のすべてに加えて、tar.lzma、tar.Z
- **追加したコーデック：** zstd、brotli、lz4、lz5、lizard（単独でも、.7zの中でも使えます）と、LZMA2の代替エンコーダーであるfast-lzma2
- 公式の7-Zipが扱える形式は、すべてそのまま使えます。

## ダウンロード

多くの方には、[リリース](https://github.com/7zStar/7-ZSTar/releases/latest)にある、すべてのユーザー向けのx64 `.msi`がおすすめです。

| | すべてのユーザー向け `.msi` | 自分だけ向け `-user.msi` | ポータブル `.zip` |
|---|---|---|---|
| 管理者権限が必要 | はい | いいえ | いいえ |
| 右クリックメニュー | Windows 11では第1階層 | 従来のメニュー（Windows 11では「その他のオプションを確認」の中） | なし |
| スタート メニューの項目 | あり | あり | なし |

どれもx86版とarm64版があります。お使いのWindowsに合うものを選んでください。64ビット版Windowsでは、x86パッケージに右クリックメニューが付かない場合があります。arm64ビルドは、まだ実機では試していません。7-ZSTarは公式の7-Zipと並べてインストールでき、公式の7-Zipには影響しません。

**初回はWindowsが警告を表示することがあります。** ファイルにはコード署名がないため、SmartScreenが止めることがあります（「Windows によって PC が保護されました」。警告の「詳細情報」を開かないと *実行* が表示されない場合があります）。また、スマート アプリ コントロールをオンにしたWindows 11では、`.msi`は完全にブロックされます。リリースごとに`SHA256SUMS`ファイルが付いているので、ダウンロードしたファイルの照合に使えます。方法と、スマート アプリ コントロールへの対処は、[インストール手順](../install/INSTALL.ja.md#未署名のパッケージsmartscreenスマート-アプリ-コントロール)で説明しています。

**第1階層のメニューについて：** Windows 11では、すべてのユーザー向けの`.msi`が、自己署名証明書で署名した小さなパッケージを追加し、その証明書を信頼済みにします。第1階層に並ぶには、Windowsがこれを求めるためです。アンインストールすると、両方とも削除されます。これを避けたい場合は、`msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`でインストールしてください。パッケージは、インストーラーを実行したアカウントに登録されます。ほかのアカウントでは、別途登録が必要です。

ファイルの関連付け、アンインストール、自分だけ向けのパッケージについては、[インストール手順](../install/INSTALL.ja.md)で説明しています。

## コマンドライン

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

PowerShellでは、スイッチを引用符で囲んでください：`7z a "-ttar.zst" backup.tar.zst docs`。囲まないと、PowerShellがスイッチを2つに分けてしまい、`.zst`という名前のファイルができます。コマンド プロンプト (cmd)では、引用符は不要です。

## 知っておきたいこと

- **「シェル コンテキストメニューに 7-ZSTar を登録」をオフにする**（ファイル マネージャーの**ツール > オプション > 7-ZSTar**）と、公式の7-Zipと同じく、右クリックメニューの項目が消えます。すべてのユーザー向けパッケージなら、ファイル マネージャーを管理者として実行すれば、もう一度オンにできます。自分だけ向けパッケージではできません（「アクセスが拒否されました。」と表示されます）。`.msi`をもう一度実行して、*Repair*（修復）を選んでください。
- **Windows 11でのサイレントインストールやリモートインストール**（SSH経由、または展開ツールから）は成功しますが、第1階層の項目は登録されません。そのため、7-ZSTarは「その他のオプションを確認」の中にしか表示されません。[詳しくはインストール手順をご覧ください](../install/INSTALL.ja.md#windows-11の右クリックメニュー)。
- **tar.br、tar.lz4、tar.lz5、tar.liz、tar.Zの展開**も、操作は一度で済みます。ただし、一時ファイルを経由し、終わったあとで削除されます。

## システム要件

Windows 7 / Server 2008 R2以降（x64、x86）。arm64ではWindows 10以降。ほかにインストールするものはありません。64ビット版のWindows 7 SP1（その後の更新プログラムを適用済み）、Windows 10、Windows 11で動作を確認しています。[確認した内容](../install/INSTALL.ja.md#システム要件)。Linuxには自分でビルドするコマンドライン版があり、macOSには対応していません。

## ドキュメント

**ヘルプ > ヘルプの表示**とF1で、公式の7-Zipのヘルプファイル`7-zip.chm`が開きます。内容は全編が「7-Zip」の表記で、7-ZSTarが追加した機能には触れていません。それについては、このページと[変更履歴](../../CHANGELOG.md)をご覧ください。ヘルプファイルが見つからない場合は、同じ項目でこの節がオンラインで開きます。

7-ZSTarを自分でビルドするには、[build/README.md](../../build/README.md)を参照してください。上流の新しいリリースを取り込む前に、[MAINTAINING.md](../../MAINTAINING.md)を読んでください。

<a id="donate"></a>

## 寄付

7-ZSTarは無料でお使いいただけます。寄付してもしなくても、使い方は同じです。時間の節約になって、お礼をしたいと思われたら、下のアドレスに暗号資産を送っていただけます。いただいた分は、私（DraftingDreamer）個人の開発費用に充てます。機能の提供やサポート、今後についての約束の見返りではありません。

EthereumまたはPolygon上のトークンなら何でも歓迎です。ETH、POL、USDT、USDCなど。どちらのネットワークでも同じアドレスです。

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="寄付アドレスのQRコード">

- Ethereum（ERC20）とPolygonでの送金のみ受け付けています。どちらも使える場合は、通常は手数料が安いPolygonをおすすめします。
- 公式のアドレスはこの1つだけで、別のアドレスへの送金をお願いすることはありません。
- ブロックチェーン上の送金は取り消せないため、返金はできません。

GitHubで7-ZSTarにスターを付けたり、友人に紹介したりしていただくのも助けになります。

## ライセンス

LGPL v3。[LICENSE](../../LICENSE)を参照してください。一部には別の条件が付きます。RAR展開にはunRARの制限があるため、RARサポート付きのビルドは純粋なLGPL v3ではありません。完全な一覧は[LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md)に、著作権表示は[NOTICE](../../NOTICE)にあります。

7-Zip、圧縮アルゴリズム、そしてオープンソース全体のために時間を注いでくださったすべての方に感謝します。皆さんがいなければ、7-ZSTarは存在しませんでした。
