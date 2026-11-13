<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# 7-ZSTar’ı Kurma

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · **Türkçe** · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*İngilizce sürümle bu belge arasında bir fark çıkarsa İngilizce sürüm esas alınır.*

[README](../readme/README.tr.md) içindeki kısa anlatımın ayrıntıları burada: sistem gereksinimleri, SmartScreen uyarısı, Akıllı Uygulama Denetimi (Smart App Control) ve indirdiğiniz dosyayı doğrulama, üç paket, Windows 11 sağ tık menüsü, dosya ilişkilendirmeleri ve kaldırma.

## Sistem gereksinimleri

**Windows 7 veya Windows Server 2008 R2, x64 ya da x86. arm64’te Windows 10.**
Başka hiçbir şeye gerek yok: C çalışma zamanı statik olarak bağlanmıştır (`-MT`), bu yüzden ikili dosyalar Windows’un kendi DLL’leri dışında hiçbir şey içe aktarmaz; ek bir yeniden dağıtılabilir paket de, .NET de gerekmez.

Bu alt sınır, paketlerin gerektirdiklerinden *türetilmiştir*; sınama ise sonraki güncellemeleri yüklü Windows 7 SP1 (aralarında PowerShell 5.1 de var), Windows 10 22H2 ve Windows 11 üzerinde, hepsi 64 bit olarak yapılmıştır. Windows 7 ve 10’da bu sınama; tüm kullanıcılar için ve kullanıcıya özel x64 `.msi` paketlerinin kurulup kaldırılmasını, kurulum sihirbazını, x64 `.zip` paketini, eklenen tüm codec’leri ve tek adımlı tar biçimlerini, sağ tık menüsünü, dosya ilişkilendirmelerini ve yardım dosyasını, bir de 64 bit Windows’ta çalışan x86 `.msi` ile `.zip` paketlerini kapsıyordu. Windows üzerinde bunun dışında hiçbir şey sınanmadı: Windows 8 veya 8.1, Windows Server, 32 bit Windows, arm64 donanımı ve bu güncellemeler olmadan Windows 7 sınanmadı. Alt sınır, ikili dosyaları hâlâ Windows XP’de yüklenebilen upstream 7-Zip’inkinden de yüksektir. Bunu üç şey belirliyor ve ikincisi hiçbir derleme ayarıyla geri alınamayandır:

- `.msi`, `InstallerVersion="500"` bildirir ve Windows Installer 5.0 “with Windows Server 2008 R2 and later and Windows 7 and later” (yani Windows Server 2008 R2 ve sonrası ile Windows 7 ve sonrasıyla birlikte) gelmiştir ([Microsoft][msi-versions]). Taşınabilir `.zip` Windows Installer’dan geçmez, ama sonraki iki maddeye bakın.
- **zstd ve fast-lzma2, yalnızca Vista’da bulunan eşzamanlama işlevlerini kullanır.** İkisi de kendi başlık dosyalarında `_WIN32_WINNT 0x0600` değerini zorlar ve `InitializeConditionVariable` / `SleepConditionVariableCS` işlevlerini doğrudan çağırır; bu yüzden codec’lerin derlenerek içine alındığı iki ikili dosya olan `7z.dll` ve `7za.exe`, Windows XP ile Server 2003’te bulunmayan dört işlevi içe aktarır. Upstream’in `7z.dll` dosyası bunların hiçbirini içe aktarmaz.
- Araç zinciri: bunlar, desteklenen hedef listesi Windows 7 ve sonrası olan Visual Studio 2022 ile derlenir; Vista ve Server 2008 için listede “No” yazar ([Microsoft][vs-targeting]). Bağlanan alt sistem sürümü x64 ve x86’da 6.0, arm64’te 6.2’dir; zaten arm64’te Windows, ne olursa olsun Windows 10’dan başlar.

Windows Vista ile Server 2008 ikisinin arasında kalır: ikili dosyalar yüklenirdi, ancak araç zinciri bunları desteklemez, yükleyici orada çalışmaz ve 7-ZSTar bunlarda sınanmamıştır.

**Linux yalnızca komut satırı derlemesi olarak desteklenir; macOS desteklenmez.**
Fork, kendi makefile’ı aracılığıyla gcc ile yerel bir `7zz` (`Alone2` konsol programı) derler; bu makefile upstream’inkini içerir ve hiçbirini değiştirmez:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Yalnızca gcc 13.3 ile Ubuntu 24.04’te (x86-64) derlenmiş ve sınanmıştır: derleme upstream’in bayraklarıyla uyarısızdır, 77 denetimlik duman testi (smoke test) geçer ve Windows’ta üretilmiş 25 ile Linux’ta üretilmiş 37 birlikte çalışabilirlik vektörü Windows’taki ile aynı sonuçları verir. Port’un dokunduğu, fork’a ait iki dosya Windows’ta hâlâ değişmeden derlenir (temiz x64 derlemesi, duman testleri ve birlikte çalışabilirlik geri okuması geçer). Grafik arayüz yoktur. Upstream’in diğer Linux hedefleri (`7za`, `7zr`, `7z.so`) desteklenmez: gcc nesne listelerinde, fork’un upstream işleyicilerinde yaptığı değişikliklerin gerektirdikleri eksiktir, bu yüzden bağlama aşamasında başarısız olmaları beklenir. Diğer mimariler, dağıtımlar ve derleyiciler doğrulanmamıştır ve macOS hiç derlenmemiştir, bu yüzden bir `MACOSX_DEPLOYMENT_TARGET` belirtilemez. Derleme adımları, testler ve bilinen sınırlar `build/linux/README.md` içindedir; Linux araçlarıyla birlikte çalışabilirlik `test/interop/REPORT.md` içindedir.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## İmzasız paketler, SmartScreen ve Akıllı Uygulama Denetimi

**Bir 7-ZSTar sürümündeki yükleyiciler ve programlar bir sertifika yetkilisi tarafından kod imzalı değildir** ve bu projenin elinde bir kod imzalama sertifikası yoktur. Bu nedenle Windows dosyayı kimin yayımladığını söyleyemez ve `.msi` dosyasını ya da `.zip` içindeki bir programı ilk kez çalıştırdığınızda Microsoft Defender SmartScreen bir uyarıyla onu durdurabilir. Microsoft’un geliştirici belgeleri, “No signature” durumunu, “Windows kişisel bilgisayarınızı korudu” (“Windows protected your PC”) başlıklı bir uyarının gösterildiği ve kullanıcının uygulama çalışmadan önce “Yine de çalıştır” (“Run anyway”) seçeneğini seçmesi gereken durumlardan biri olarak listeler ([Microsoft][smartscreen-rep]). Kurumsal ilke bu seçeneği büsbütün kaldırabilir; böyle bir bilgisayarda onu yöneten kişiye sorun.

Bir sürümde imzalı olan tek şey, tüm kullanıcılar için olan `.msi` içinde bulunan ve 7-ZSTar’ı Windows 11 sağ tık menüsünün ilk düzeyine koyan küçük pakettir. Sertifikası kendinden imzalıdır ve yalnızca o paket derlenirken üretilir; dolayısıyla bir sertifika yetkilisinin imzası değildir ve paketi kimin derlediği hakkında hiçbir şey söylemez; ne yaptığı ve nasıl reddedileceği için [Windows 11 sağ tık menüsü](#windows-11-sağ-tık-menüsü) bölümüne bakın.

Uyarı bir dosyanın kötü olduğunun kanıtı değildir, uyarının olmaması da dosyanın iyi olduğunun kanıtı olmazdı. Kendi başınıza doğrulayabileceğiniz şey, elinizdeki kopyanın sürüm sayfasında yayımlananla birebir aynı olduğudur. Her sürümde `SHA256SUMS` adlı bir dosya bulunur: her paket için bir satır, bir SHA-256 karması ve ardından dosya adı.

1. Paketi ve `SHA256SUMS` dosyasını aynı sürüm sayfasından, aynı klasöre indirin.
2. O klasörde PowerShell’i açın ve karşılaştırın. Adı, indirdiğiniz dosyanın adıyla değiştirin:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True`, karmaların aynı olduğu anlamına gelir. Bunun yerine karmalara kendiniz bakmak isterseniz `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` komutunu çalıştırın ve aynı dosya adını `SHA256SUMS` içinde bulun; karşılaştırma büyük/küçük harf ayrımı yapmaz.
3. `False` alırsanız ya da dosya adı `SHA256SUMS` içinde yoksa çalıştırmayın: dosyayı silin ve yeniden indirin. Yine de eşleşmezse lütfen [SECURITY.md](../../SECURITY.md) dosyasında anlatıldığı gibi bildirin.

`SHA256SUMS` yalnızca o sürüme yüklenen dosyaları kapsar. Aynı etiketi (tag) kendiniz derlerseniz farklı karmalar elde edersiniz (sağ tık menüsü paketi her derlemede yeni bir sertifikayla imzalanır); kendiniz derlemeyi tercih ederseniz kaynak kodu her sürümle birlikte yayımlanır: bkz. [build/README.md](../../build/README.md).

Karmalar eşleştikten ve dosyanın nereden geldiğinden memnun kaldıktan sonra:

- **`.msi`**: her zamanki gibi başlatın. SmartScreen durdurursa yine de çalıştırma seçeneğini seçin (İngilizce bir Windows’ta “Run anyway”). Uyarı penceresinin önce genişletilmesi gerekebilir: sınanan Windows 10 makinesinde, iletisinin altındaki bağlantıya tıklanana kadar yalnızca dosyayı çalıştırmama düğmesi sunuyordu. Tüm kullanıcılar için olan `.msi` bundan sonra, diğer yükleyiciler gibi yönetici onayı ister.
- **`.zip`**: arşivi çıkarın ve klasörden `7zFM.exe` ya da `7z.exe` dosyasını başlatın. İçindeki programlar da imzasızdır; bu yüzden Windows her birini ilk kez başlattığınızda aynı uyarıyı gösterebilir.

SmartScreen yalnızca imzalara göre değil, bir dosyanın ne kadar tanındığına göre de uyarır; az sayıda kişi tarafından indirilmiş bir dosya imzalı olsa bile uyarıyı tetikleyebilir. Buradaki hiçbir şey bunu değiştirmez ve yukarıdaki adımların hiçbiri SmartScreen’i kapatmaz.

### Windows 11’de Akıllı Uygulama Denetimi

Bazı Windows 11 bilgisayarlarında **Akıllı Uygulama Denetimi** (Smart App Control) adlı daha sıkı bir koruma açıktır. Açıkken Windows, Microsoft’un bulut hizmeti kefil olamadıkça imzasız dosyaları engeller; yeni bir sürümün genellikle böyle bir kaydı olmaz ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). SmartScreen uyarısından farklı olarak bu engelde dosyayı yine de çalıştırma seçeneği yoktur ve Microsoft’un SSS sayfası, tek tek bir uygulama için Akıllı Uygulama Denetimi’ni atlatmanın bir yolu olmadığını söyler.

Akıllı Uygulama Denetimi açıkken 7-ZSTar 26.05.1 Windows 11 Pro 25H2 (build 26200.8037) üzerinde denendiğinde olanlar:

- **`.msi` yükleyicileri engellendi**, hem tüm kullanıcılar için olan hem de kullanıcıya özel olan. Geleneksel Çince bir Windows’ta Windows Installer 「系統禁用此安裝。請連絡系統管理員。」 iletisini verdi ve bir Windows Güvenliği bildirimi, Windows dosyayı kimin yayımladığını söyleyemediği ve dosya Windows’un tanıdığı bir uygulama olmadığı için Akıllı Uygulama Denetimi’nin dosyayı engellediğini bildirdi. Devam etme seçeneği yoktu ve `msiexec /i ... /qn` komutu error 1625 döndürdü. Bu ileti, Windows Installer’ın 1625 numaralı dizesidir (string 1625); İngilizce bir Windows’ta aynı dize “The system administrator has set policies to prevent this installation.” şeklindedir (Windows Installer’ın İngilizce kaynaklarından okundu, ekranda görülmedi).
- **`.zip` içindeki bir program çalıştı.** Taşınabilir `.zip` paketinden çıkarılan `7zFM.exe`, aynı testte normal şekilde başladı. Windows’un imzasız bir programın çalışmasına izin verip vermemesi, o dosya hakkındaki kendi değerlendirmesidir; dolayısıyla bu, sizin bilgisayarınızda farklı olabilir.
- Akıllı Uygulama Denetimi açıldıktan hemen sonra `.msi`, engellenmeye başlamadan önce birkaç dakika boyunca kurulabildi. Nedeni bulunamadı; bu yüzden denetimi açtıktan hemen sonra gelen bir başarı, yükleyiciye izin verildiği anlamına gelmez.

Dolayısıyla Akıllı Uygulama Denetimi’nin açık olduğu bir bilgisayarda **yükleyiciler kurulamaz** ve `SHA256SUMS` dosyasını denetlemek bunu değiştirmez. Değiştiren şey, Akıllı Uygulama Denetimi’ni Windows Güvenliği uygulamasının Akıllı Uygulama Denetimi ayarları bölümünden kapatmaktır (sınanan Geleneksel Çince Windows’ta: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). Testte Kapalı seçeneğini seçmek hemen, yeniden başlatma gerekmeden etkili oldu ve yükleyiciler ardından kurulabildi. Bu, bilgisayarın tamamı için geçerli bir ayardır ve burada hiçbir şey sizden bunu değiştirmenizi istemez: karar sizindir ya da yönetilen bir bilgisayarda yöneticinizindir.

Yeniden açılıp açılamayacağını önceden bilmekte de fayda var. Microsoft’un SSS sayfası, son Windows güncellemelerinin Akıllı Uygulama Denetimi’nin Windows’u temiz kurmadan yeniden açılmasına izin verdiğini söyler; bu güncellemelerin olmadığı bir sürümde kapatmak kalıcı olabilir. Burada sınanan derlemede, kapattıktan sonra da açma seçeneği sunulmaya devam etti; bu bir test sonucudur, sizin sürümünüz için verilmiş bir söz değildir.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Kurulum

Üç paket vardır; hepsi `installer\Build-Package.ps1` ile derlenir (kullanıcıya özel olan `-PerUser` ile):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Kurulduğu kapsam | her hesap | kurulumu yapan hesap | - |
| Dosya Gezgini sağ tık menüsü | evet | evet, yalnızca klasik menü ([aşağıda](#kullanıcıya-özel-paket)) | hayır |
| Başlat Menüsü girişi | evet | evet | hayır |
| Yönetici gerekir | evet | hayır | hayır |
| Kaldırma | Ayarlar’da *Yüklü uygulamalar* | Ayarlar’da *Yüklü uygulamalar* | klasörü silin |

*Yüklü uygulamalar*, Windows 11’deki addır. Windows 10 aynı sayfaya *Uygulamalar ve Özellikler* der; Windows 7’de ise Control Panel (Denetim Masası) içindeki *Programs and Features* (Programlar ve Özellikler) sayfasıdır.

Windows’un kendisiyle eşleşen paketleri kullanın: 32 bit Windows’ta x86, 64 bit Windows’ta x64, Arm üzerinde Windows’ta arm64 (arm64 paketleri derlenmiştir ancak hiç çalıştırılmamıştır). x86 kabuk uzantısı 32 bittir ve 64 bit Dosya Gezgini onu yükleyemez; bu yüzden 64 bit Windows’ta x86 `-user.msi` paketinin hiç sağ tık menüsü yoktur, x86 `.msi` paketinin ise yalnızca Windows 11’de ve yalnızca Windows 11 paketini kaydettirmiş hesaplar için (kurulumu yapan hesap ya da aşağıda anlatılan `-Register` komutunu çalıştırmış bir hesap) vardır.

MSI her zaman `Program Files\7-ZSTar` içine kurulur: kullanıcıya özel paketin aksine klasör seçeneği sunmaz ve komut satırındaki `INSTALLFOLDER` değerini yok sayar; çünkü o klasör, yükleyicinin SYSTEM olarak çalıştırdığı bir betiği ve her kullanıcının Dosya Gezgini’nin yüklediği bir DLL’yi barındırır ve başka bir yerde (örneğin `C:\` altında) oluşturulan bir klasöre her kullanıcı yazabilir. Kendi kabuk uzantısı CLSID’sini ve kendi `Software\7-ZSTar` kayıt defteri kovanını kaydeder ve her sağ tık menüsü anahtarına `7-ZSTar` adını verir; bu yüzden resmî 7-Zip ile ne çakışır ne de onunkini kaldırır. Bkz. [installer/GUIDS.md](../../installer/GUIDS.md).

Normal bir kurulum sihirbazı çalıştırır: welcome, licence, setup type, optional feature tree, finish (karşılama, lisans, kurulum türü, isteğe bağlı özellik ağacı, bitiş). Sessiz kurulum da değişmeden çalışır (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), çünkü msiexec sessiz kipte tüm arayüz dizisini atlar. Sihirbaz yalnızca İngilizcedir, başka bir dile ayarlı Windows’ta da (Geleneksel Çince Windows 10’da görüldü; `.msi` başka hiçbir dille derlenmemiştir) ve bitiş sayfasında *Launch 7-ZSTar File Manager* (7-ZSTar Dosya Yöneticisi’ni başlat) varsayılan olarak işaretlidir.

### Windows 11 sağ tık menüsü

Windows 11’de giriş, resmî 7-Zip ile WinRAR’ın hâlâ durduğu *Daha fazla seçenek göster* altına gömülü değil, ilk düzey menüdedir. Windows 11, bir kabuk uzantısını orada yalnızca paket kimliğiyle (package identity) geldiğinde listeler; bu yüzden MSI, programın yanında yalnızca kimlik içeren küçük bir MSIX paketi getirir ve kurulum sırasında onu kaydeder. Klasik kayıt da korunur. Girişi, tek düzeyli ve *Daha fazla seçenek göster* bulunmayan Windows 10 ve Windows 7 menüsüne koyan ve eski sağ tık menüsünü geri getirmiş olanlar için çalışmasını sürdüren de odur.

Bu paket **kendinden imzalı bir sertifikayla** imzalanmıştır ve yükleyici onu `LocalMachine\TrustedPeople` içine koyar; Windows, imzasını güvenilir bir şeye bağlayamadığı bir paketi dağıtmaz. Kaldırma, sertifikayı paketle birlikte kaldırır. Windows 10 ve Windows 7’de yükleyici bunların hiçbirini yapmaz: sertifika eklemez, paket kaydetmez ve menüyü yalnızca klasik kayıt sağlar.

Kendinden imzalı bir sertifikaya güvenmek istemiyorsanız yalnızca o kısmı reddedin, geri kalan her şeyi koruyun:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

O zaman yalnızca klasik menüyü alırsınız; yani Windows 11’de 7-ZSTar girişi sağ tık menüsünde *Daha fazla seçenek göster* altında olur. İlk düzey girişi sonradan açmak ya da normal bir kurulumdan sonra geri almak için:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Bu sertifikaya güvenmek, Windows’un aynı anahtarla imzalanmış **başka herhangi bir** paketi de uyarı vermeden kabul edeceği anlamına gelir. Yalnızca bu tek paket için kullanılır ve kaldırma onu geri alır; ama kabul ettiğiniz şey budur: reddetmenin yolu yukarıdaki `SPARSE=0` seçeneğidir.

Paket kaydı kullanıcı başınadır ve yükleyici onu yalnızca kurulumu yapan kişi için çalıştırır. İki sonucu var:

- Aynı makinedeki ikinci bir hesap, aynı betiği `-Register` ile çalıştırana kadar yalnızca klasik menüyü alır.
- Kaldırma, kaydı yalnızca kaldırmayı yapan kişi için siler. Başka biri kaydettirmişse onun kaydı kaldırmadan sonra da kalır ve artık var olmayan bir klasörü gösterir; o hesap bunu `Get-AppxPackage 7-ZSTar | Remove-AppxPackage` ile temizler.

**Bilinen sınırlama: ilk düzey menü yalnızca kurulum etkileşimli, oturum açılmış bir oturumda çalıştığında kaydedilir.** Tüm kullanıcılar için olan `.msi` paketini uzak ya da etkileşimsiz bir oturumdan (SSH üzerinden ya da bir yönetim aracından sessiz dağıtımla) kurmak yine başarılı görünür, ancak Windows 11 paketi kaydedilmez; bu yüzden yalnızca *Daha fazla seçenek göster* altındaki klasik menü görünür. Testte, bir SSH oturumundan (oturum 0) `msiexec /i ... /qn` 0 koduyla çıktı, `Setup-ShellIntegration.ps1` ise `registration failed: 0x80070005` (erişim engellendi) bildirdi; aynı `.msi` bir yöneticinin konsol oturumundan kurulduğunda normal şekilde kaydedildi.

`-Status` neyin yerinde olduğunu ve neyin olmadığını yazdırır.

### Kullanıcıya özel paket

`7-ZSTar-<version>-<arch>-user.msi` yalnızca geçerli hesap için, Kullanıcı Hesabı Denetimi (UAC) istemi olmadan `%LOCALAPPDATA%\Programs\7-ZSTar` içine kurulur. Kaydettiği her şey `HKCU` altına gider; paket `HKLM` altına hiçbir şey yazmaz (Windows Installer’ın kendi kayıtları hariç). Makine geneli paketin yaptığı gibi yapmadıkları:

- **Windows 11 ilk düzey menüsü yok.** Windows 11’de 7-ZSTar, sağ tık menüsünde *Daha fazla seçenek göster* altındadır. İlk düzey giriş, kendinden imzalı sertifikaya makine genelinde güvenilmesini gerektirir ve bu bir yönetici ister: Windows 11’de ölçüldüğü üzere `CurrentUser\TrustedPeople` içindeki bir sertifika Windows’un paketi dağıtması için yetmez. Bu yüzden kullanıcıya özel paket onu dışarıda bırakır.
- **Makinede ikisinden yalnızca biri.** Her paket, diğeri kuruluyken kurulmayı reddeder; birini kurmadan önce diğerini kaldırın. Makine geneli paket yalnızca onu çalıştıran hesabın kullanıcıya özel kopyasını görebilir; bu yüzden başka bir hesabın kullanıcıya özel kurulumu algılanmaz.
- **Grup İlkesi menüsünü gizleyebilir.** `EnforceShellExtensionSecurity` ayarlı olan yerlerde Dosya Gezgini yalnızca makine genelindeki *Approved* anahtarı altında listelenen kabuk uzantılarını yükler; kullanıcıya özel bir kurulum buraya yazamaz, bu yüzden sağ tık menüsü görünmez. Orada makine geneli paketi kullanın.
- **Araçlar > Ayarlar... > Sistem’de bir biçimi temizlemek, 7-ZSTar’ın o biçim için sunduğu seçeneği de kaldırır.** Orada bir biçimi temizlediğinizde (hücresine boşalana kadar tıklayın, ardından Tamam), dosya yöneticisi `HKCU\Software\Classes\.<ext>` ve `7-ZSTar.<ext>` anahtarlarının tamamını siler; kullanıcıya özel bir kurulumda bu anahtarlar, paketin Ayarlar > Uygulamalar > Varsayılan uygulamalar ve *Birlikte aç* listesi için kaydettiklerini de barındırır. 7-ZSTar bunun üzerine o biçim için *Birlikte aç* listesinden düşer ve Varsayılan uygulamalar sayfasında o biçim için boş bir giriş görünür. Kurulumu onarmak onu geri getirir (`.msi` dosyasını yeniden çalıştırın ve *Repair* (Onar) seçin). Daha iyisi, dosya türlerini dosya yöneticisinde değil Varsayılan uygulamalar sayfasında atamaktır. Makine geneli paketin de bir yerde aynı zayıf noktası vardır; aşağıda dosya ilişkilendirmeleri bölümünde anlatılıyor.

### Dosya ilişkilendirmeleri ve kaldırmanın onlara yaptığı

**Bunları Ayarlar > Uygulamalar > Varsayılan uygulamalar sayfasında belirleyin.** Windows 11’de orada 7-ZSTar yazın; açabildiği tüm biçimler atanmak üzere listelenir. Windows 10’da 7-ZSTar, aynı sayfada *Set defaults by app* (Uygulamaya göre varsayılanları belirle) altında listelenir; *Manage* (Yönet) düğmesi biçimlerini gösterir. Windows 7’de Ayarlar uygulaması yoktur: 7-ZSTar, Control Panel > Varsayılan Programlar > *Varsayılan programlarınızı ayarlayın* altında listelenir ve bu kılavuzda *Varsayılan uygulamalar* ifadesi orada buna karşılık gelir. Biçimleri bu iki sayfadan atamak sınanmamıştır. Yükleyici, 7-ZSTar’ı bir Varsayılan Programlar uygulaması olarak kaydeder (her biçim için simgesi ve açma komutuyla bir ProgID, her uzantının *Birlikte aç* listesinde bir giriş ve Windows’un okuduğu Capabilities bloğu), ancak bilerek hiçbir dosya türü üzerinde hak iddia etmez: arşivlerinizi hangi programın açacağı sizin kararınızdır ve 7-ZSTar ile resmî 7-Zip’in birbirinin yoluna çıkmamasını sağlayan da budur. Başka hiçbir program açmayı önermiyorsa Windows yine de bir biçimi kendiliğinden 7-ZSTar’a yönlendirebilir: sınanan Windows 10 ve Windows 7 makinelerinde, `.7z` uzantısını başka hiçbir şeyin kaydetmediği durumda bir `.7z` dosyası 7-ZSTar’ın simgesini gösterdi ve çift tıklandığında Windows hangi programın kullanılacağını sormadan onda açıldı.

**Dosya yöneticisindeki Araçlar > Ayarlar... > Sistem, Windows 11’de çoğunlukla çalışmaz**; bu, buradaki bir hata değil bir Windows kuralıdır. `HKCU\Software\Classes` içine bir `7-ZSTar.<ext>` ProgID’si yazar ve makinenin zaten tanıdığı her uzantıyı (her arşiv biçimi tanınır) Windows 11 yok sayar: `AssocQueryString` `Unknown` yanıtını verir ve Dosya Gezgini boş genel simgeyi çizer. Windows’un onun yerine saydığı şey, yalnızca Windows’un hesaplayabildiği bir karmayla damgalanmış `UserChoice` anahtarıdır; orada tek yolun Ayarlar arayüzü olmasının nedeni budur. Hiçbir uygulama bir tane yazamaz: 7-ZSTar da, 7-Zip de, hiçbir yükleyici de. Windows 10 ve Windows 7 testte farklı davrandı: `.7z` ve `.zst` dosya yöneticisinde, başka bir program seçilmeden atandığında `AssocQueryString` ikisi için de `7zFM.exe` döndürdü.

**Bir biçimi *Tüm kullanıcılar* sütununda temizlemek, makine geneli paketin o biçim için kendi kaydını kaldırır.** Bu sütun, makine geneli paketin duyurduğu ProgID’leri ve *Birlikte aç* girişlerini tuttuğu `HKLM\Software\Classes` içine yazar; orada bir biçimi temizlemek (dosya yöneticisinin *Yönetici olarak çalıştır* ile başlatılmasını gerektirir) o anahtarları bütünüyle, her hesap için siler. Onarım, kullanıcıya özel paket için aynı anahtarları geri getirdi; bunun için ölçülmedi.

**Değişiklik yaptıktan sonra boş kalan bir simge**, Dosya Gezgini’nin simge önbelleğinden de kaynaklanıyor olabilir; bu önbellek, zaten önbelleğe aldığı bir DLL’nin değiştirildiğini fark etmez ve `ie4uinit.exe -show` onu güvenilir biçimde temizlemez. Dosya Gezgini’ni kapatın, `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db` dosyalarını silin, yeniden başlatın.

**Kaldırma, ulaşabildiği ilişkilendirmeleri kaldırır**: kaldırmayı yapan kişiye ait `7-ZSTar.*` ProgID’lerini ve yalnızca hâlâ onları gösteren dosya türlerini; yani bu arada başka bir programa verilmiş bir biçime dokunulmaz. Makine geneli paketin kaldırılması, başka bir yerde hâlâ var olan bir 7-ZSTar kopyasını açan bir ProgID’ye de dokunmaz; örneğin `.zip` paketinden gelen taşınabilir bir kopya, o kopyanın kendi **Araçlar > Ayarlar... > Sistem** ayarıyla kurulmuşsa. Kullanıcıya özel paket bunu yapamaz: ProgID’leri aynı `HKCU` anahtarlarıdır (yukarıda *Kullanıcıya özel paket* bölümüne bakın) ve kaldırma, onları en son kim yazmış olursa olsun siler. Bunları geride bırakmak, o türleri simgesi ve komutu silinmiş bir yürütülebilir dosya olan bir ProgID’ye yönlendirirdi; bu da boş bir simge ve çift tıklamada bir hata demektir. Diğer hesapların ilişkilendirmelerine ulaşılamaz; program gitmeden önce kendilerininkini `Setup-ShellIntegration.ps1 -RemoveAssociations` ile temizleyebilirler. `msiexec /x ... KEEPASSOC=1` bunu atlar ve bir yükseltme bunu asla yapmaz.

**Bilinen sınırlama: diğer hesaplar kendi belirledikleri ilişkilendirmeleri korur.** Makine geneli paketin kaldırılması, dosya yöneticisinde **Araçlar > Ayarlar... > Sistem** altında yalnızca kaldırmayı çalıştıran hesabın kendi sütununda (sütun başlığı hesap adıdır) belirlediklerini temizler. Orada ilişkilendirme belirlemiş diğer her hesap bunları korur ve bunlar kaldırılan programı gösterir; bu yüzden bir `.7z` dosyasına çift tıklamak Windows’a hangi programın kullanılacağını sordurur. Her hesap kendisininkini kaldırmadan **önce** şununla temizlemelidir:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

bu komut yalnızca 7-ZSTar’ın girişlerini kaldırır; ya da sonradan türleri yeniden Ayarlar > Uygulamalar > Varsayılan uygulamalar altında atayabilir. Bunu bunun yerine dosya yöneticisinde yapmak, kendi sütunundaki 7-ZSTar gösteren her hücreye boşalana kadar tıklamak, ardından Tamam demek anlamına gelir; tüm satırları seçip “+” düğmesine basmayın: bu, seçili her satıra tek bir durumu uygular ve dolayısıyla resmî 7-Zip gibi başka bir programa ait biçimleri de temizler.

**Tüm kullanıcılar** sütununda belirlenen ilişkilendirmelere kaldırma temizliği hiç dokunmaz; bunlar her hesabı kaldırılmış programa yönlendirir durumda kalır. Herhangi birini belirlemiş bir yönetici, kaldırmadan önce bu hücreleri, *Yönetici olarak çalıştır* ile başlatılmış bir dosya yöneticisinden temizlemeli, ardından Tamam demelidir; `-RemoveAssociations` bu sütuna ulaşmaz. Kaldırmadan hemen önce temizlemek, paketin oradaki kendi kaydını da silmesine (yukarıda) rağmen zararsızdır, çünkü kaldırma onu zaten siler. Kullanıcıya özel paketin diğer hesaplar sorunu yoktur ve resmî 7-Zip de aynı şekilde davranır.

## Diller

Her paket, upstream’in çevirilerini, yani 90’ı aşkın dili taşır. Birini **Araçlar > Ayarlar... > Dil** altından seçin; MSI ayrıca *Custom* (özel) kurulumda bunları dışarıda bırakmanıza izin verir. 7-ZSTar ilk çalıştırmada sistem dilini izlemeye çalışır, ancak Windows’un “language for non-Unicode programs” (Unicode olmayan programlar için dil) ayarı ile “Bölgesel biçim” ayarı birbiriyle uyuşmadığında bu algılama vazgeçer ve İngilizce kalır; dili elle seçmek her zaman çalışır.

7-ZSTar’ın kendi eklediği dizeler (zstd düzeyi ve sözlük alanları, yeni arşiv biçimi adları) için upstream çevirisi yoktur ve İngilizce kalır. İstisna, “7-ZSTar Hakkında...” iletişim kutusundaki **Bağış** ve **Web sitesi** düğmeleridir: 92 dilin 67’sinde ikisi için de bir karşılık vardır, diğer 25’inde İngilizce görünür (bunları `Lang/UPSTREAM.md` listeler).
Çeviriler buraya yazılmamıştır, dışarıdan alınmıştır (vendored): bkz. [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
