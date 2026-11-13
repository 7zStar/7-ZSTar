<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · **Türkçe** · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*İngilizce sürümle bu belge arasında bir fark çıkarsa İngilizce sürüm esas alınır.*

**Modern Windows 11 kullanıcıları için daha dostane bir 7-Zip fork’u: sağ tık menüsünün ilk düzeyinde yer alır, zstd ile sıkıştırır, tar.zst’yi tek geçişte üretir.**

[İndir](https://github.com/7zStar/7-ZSTar/releases/latest) · [Web sitesi](https://www.7zstar.com) · [Değişiklik günlüğü](../../CHANGELOG.md)

## Neden 7-ZSTar

- **Artık “Daha fazla seçenek göster” yok.** Windows 11’de 7-ZSTar, sağ tık menüsünün tam ilk düzeyinde yer alır.
- **Tek adımda tar.zst.** Bir klasörü .tar.zst olarak sıkıştırmak ya da bir .tar.zst’yi açmak tek adımdır; diskte .tar kalmaz. Resmî 7-Zip .tar.zst oluşturamaz, açarken de .tar üzerinden iki adımda ilerler.
- **7z’den yaklaşık 10× hızlı.** Gerçek proje klasörlerinde tar.zst 10 ila 18 kat daha hızlı sıkıştırdı.

## Hız

| Klasör | Dosya | Ham boyut | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 sn / 76.7 MB | 38.4 sn / 51.8 MB | **3.8 sn** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 sn / 107.8 MB | 54.8 sn / 65.7 MB | **3.6 sn** / 83.4 MB |
| Python `.venv` (büyük ikili dosyalar) | 11,654 | 671 MB | 25.5 sn / 249.5 MB | 100.8 sn / 167.2 MB | **5.6 sn** / 210.9 MB |

tar.zst, zip’ten %15 ila %23 daha küçük çıktı ve daha yavaş olmadı. En küçük dosyaları hâlâ 7z üretiyor (tar.zst %15 ila %27 daha büyüktü), ama çok daha uzun sürdü. Açma süresi üçünde de hemen hemen aynıydı.

Üçü de varsayılan ayarlarla; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, 3 çalıştırmanın medyanı, 2026-11.

## Biçimler

- **Tek adımda sıkıştırma:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Tek adımda açma:** bunların hepsi, ayrıca tar.lzma ve tar.Z
- **Eklenen codec’ler:** zstd, brotli, lz4, lz5 ve lizard (tek başlarına ya da .7z içinde), ayrıca alternatif bir LZMA2 kodlayıcısı olan fast-lzma2
- Resmî 7-Zip’in işlediği her biçim yine çalışır.

## İndir

Çoğu kişi için doğru seçim, [Sürümler](https://github.com/7zStar/7-ZSTar/releases/latest) sayfasındaki tüm kullanıcılar için x64 `.msi` dosyasıdır.

| | Tüm kullanıcılar `.msi` | Yalnızca siz `-user.msi` | Taşınabilir `.zip` |
|---|---|---|---|
| Yönetici hakları gerekir | Evet | Hayır | Hayır |
| Sağ tık menüsü | Windows 11’de ilk düzey | Klasik menü (Windows 11’de “Daha fazla seçenek göster” altında) | Yok |
| Başlat Menüsü girişi | Evet | Evet | Hayır |

Her biri x86 ve arm64 için de vardır; Windows’unuzla eşleşeni seçin. 64 bit Windows’ta x86 paketlerinde sağ tık menüsü olmayabilir; arm64 derlemeleri henüz gerçek donanımda denenmedi. 7-ZSTar, resmî 7-Zip’i etkilemeden onunla yan yana kurulur.

**Windows ilk seferde sizi uyarabilir.** Dosyalar kod imzalı değildir; bu yüzden SmartScreen onları durdurabilir (“Windows kişisel bilgisayarınızı korudu”; *Yine de çalıştır* seçeneğini görmek için uyarıyı genişletmeniz gerekebilir) ve Akıllı Uygulama Denetimi açık olan Windows 11’de `.msi` doğrudan engellenir. Her sürümde, indirdiğiniz dosyayı karşılaştırabileceğiniz bir `SHA256SUMS` dosyası bulunur. Bunun nasıl yapıldığını ve Akıllı Uygulama Denetimi için ne yapılacağını [kurulum belgesi](../install/INSTALL.tr.md#i̇mzasız-paketler-smartscreen-ve-akıllı-uygulama-denetimi) anlatır.

**İlk düzey menü hakkında:** Windows 11’de tüm kullanıcılar için `.msi`, kendinden imzalı bir sertifikayla imzalanmış küçük bir paket ekler ve bu sertifikaya güvenir; Windows’un ilk düzey için istediği budur. Kaldırma ikisini de siler. İstemezseniz `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0` ile kurun. Paket, yükleyiciyi çalıştıran hesap için kaydedilir; diğer hesaplar onu ayrıca kaydeder.

Dosya ilişkilendirmeleri, kaldırma ve kullanıcıya özel paket [kurulum belgesinde](../install/INSTALL.tr.md) ele alınır.

## Komut satırı

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

PowerShell’de anahtarı tırnak içine alın: `7z a "-ttar.zst" backup.tar.zst docs`. Tırnak olmazsa PowerShell onu ikiye böler ve `.zst` adlı bir dosya elde edersiniz. Komut İstemi (cmd) için tırnak gerekmez.

## Bilmekte fayda var

- **“7-ZSTar'i sağ tık menüsüne ekle” seçeneğini kapatmak** (dosya yöneticisinde **Araçlar > Ayarlar... > 7-ZSTar**), resmî 7-Zip’te olduğu gibi sağ tık girişini kaldırır. Tüm kullanıcılar paketinde, dosya yöneticisini *Yönetici olarak çalıştır* ile başlatarak yeniden açabilirsiniz. Kullanıcıya özel pakette açamazsınız (“Erişim engellendi.”); `.msi` dosyasını yeniden çalıştırın ve *Repair* (onar) seçin.
- **Windows 11’de sessiz ya da uzaktan kurulumlar** (SSH üzerinden ya da bir dağıtım aracından) başarılı olur, ama ilk düzey giriş kaydedilmez; bu yüzden 7-ZSTar yalnızca “Daha fazla seçenek göster” altında görünür. [Ayrıntılar kurulum belgesinde](../install/INSTALL.tr.md#windows-11-sağ-tık-menüsü).
- **tar.br, tar.lz4, tar.lz5, tar.liz veya tar.Z açmak** sizin için yine tek adımdır, ancak işlem sonradan silinen geçici bir dosyadan geçer.

## Sistem gereksinimleri

Windows 7 / Server 2008 R2 veya üstü (x64, x86) ya da arm64 için Windows 10 veya üstü. Başka bir şey kurmanız gerekmez. 64 bit Windows 7 SP1 (sonraki güncellemeler yüklü), Windows 10 ve Windows 11 üzerinde sınanmıştır; [nelerin sınandığı](../install/INSTALL.tr.md#sistem-gereksinimleri). Linux’ta kendiniz derlediğiniz bir komut satırı sürümü vardır; macOS desteklenmez.

## Belgeler

**Yardım > İçerik...** ve F1, resmî 7-Zip’in yardım dosyası olan `7-zip.chm` dosyasını açar. Baştan sona “7-Zip” der ve 7-ZSTar’ın eklediklerini kapsamaz; bunlar için bu sayfaya ve [değişiklik günlüğüne](../../CHANGELOG.md) bakın. Yardım dosyası yoksa aynı girişler bu bölümü çevrimiçi açar.

7-ZSTar’ı kendiniz derlemek için [build/README.md](../../build/README.md) dosyasına bakın; yeni bir upstream sürümünü birleştirmeden önce [MAINTAINING.md](../../MAINTAINING.md) dosyasını okuyun.

<a id="donate"></a>

## Bağış

7-ZSTar bağış yapsanız da yapmasanız da ücretsizdir. Size biraz zaman kazandırdıysa ve teşekkür etmek isterseniz aşağıdaki adrese kripto para gönderebilirsiniz. Bu para bana, DraftingDreamer’a gider; kendi geliştirme masraflarım için kullanılır ve özellik, destek ya da bundan sonrası için herhangi bir söz satın almaz.

Ethereum veya Polygon üzerindeki her token kabul edilir: ETH, POL, USDT, USDC ya da başkası. Adres iki ağda da aynıdır.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Bağış adresinin QR kodu">

- Yalnızca Ethereum (ERC20) ve Polygon üzerindeki transferler kabul edilir. İkisini de kullanabiliyorsanız Polygon’da ücretler genellikle daha düşüktür.
- Tek resmî adres budur ve sizden başka bir adrese göndermenizi asla istemem.
- Zincir üzerindeki transferler geri alınamaz, bu yüzden iade edilemez.

7-ZSTar’a GitHub’da yıldız vermek ya da bir arkadaşınıza söylemek de yardımcı olur.

## Lisans

LGPL v3, bkz. [LICENSE](../../LICENSE). Bazı parçalar başka koşullarla gelir: RAR açma, unRAR kısıtlamasını taşır; bu yüzden RAR desteği olan bir derleme yalnızca LGPL v3 değildir. Tam liste [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md) dosyasında, telif hakkı bildirimleri ise [NOTICE](../../NOTICE) dosyasındadır.

7-Zip’e, sıkıştırma algoritmalarına ve genel olarak açık kaynağa zaman ayıran herkese teşekkürler. Siz olmasaydınız 7-ZSTar var olmazdı.
