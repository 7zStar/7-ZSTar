<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Menginstal 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · **Bahasa Indonesia** · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Jika isi dokumen ini berbeda dengan versi bahasa Inggris, yang berlaku adalah versi bahasa Inggris.*

Dokumen ini memuat rincian di balik versi singkat di [README](../readme/README.id.md): persyaratan sistem,
peringatan SmartScreen, Kontrol Aplikasi Pintar dan cara memeriksa unduhan, tiga paket, menu klik kanan
Windows 11, asosiasi file, dan uninstal.

## Persyaratan sistem

**Windows 7 atau Windows Server 2008 R2, x64 atau x86. Pada arm64, Windows 10.**
Tidak perlu apa pun lagi: C runtime di-link secara statis (`-MT`), sehingga
biner tidak mengimpor apa pun selain DLL bawaan Windows - tanpa redistributable, tanpa .NET.

Batas minimum itu *diturunkan* dari apa yang dibutuhkan paket-paketnya, dan sudah
diuji di Windows 7 SP1 dengan pembaruan lanjutan terpasang (termasuk PowerShell 5.1),
Windows 10 22H2, dan Windows 11, semuanya 64-bit. Di Windows 7 dan 10, pengujian itu
mencakup instal dan uninstal `.msi` x64 untuk semua pengguna maupun per pengguna,
wizard instalasi, `.zip` x64, setiap codec tambahan dan format tar satu langkah,
menu klik kanan, asosiasi file, dan file bantuan, serta `.msi` dan `.zip` x86 yang
berjalan di Windows 64-bit. Hal lain belum diuji di Windows: tidak di
Windows 8 atau 8.1, Windows Server, Windows 32-bit, perangkat keras arm64, maupun Windows 7
tanpa pembaruan tersebut. Batas minimum ini juga lebih tinggi daripada 7-Zip upstream, yang
binernya masih bisa dimuat di Windows XP. Tiga hal yang menetapkannya, dan yang kedua
adalah yang tidak bisa dibatalkan oleh pengaturan build mana pun:

- `.msi` mendeklarasikan `InstallerVersion="500"`, dan Windows Installer 5.0 dirilis
  "with Windows Server 2008 R2 and later and Windows 7 and later"
  ([Microsoft][msi-versions]). `.zip` portabel tidak melalui
  Windows Installer, tetapi lihat dua poin berikutnya.
- **zstd dan fast-lzma2 memakai sinkronisasi yang hanya ada sejak Vista.** Keduanya memaksa
  `_WIN32_WINNT 0x0600` di header masing-masing dan memanggil
  `InitializeConditionVariable` / `SleepConditionVariableCS` secara langsung, sehingga
  `7z.dll` dan `7za.exe` - dua biner yang memuat codec ini - mengimpor empat fungsi
  yang tidak dimiliki Windows XP dan Server 2003. `7z.dll` upstream tidak mengimpor
  satu pun dari fungsi itu.
- Toolchain: biner ini dibangun dengan Visual Studio 2022, yang daftar target
  yang didukungnya adalah Windows 7 dan yang lebih baru - Vista dan Server 2008 adalah "No"
  ([Microsoft][vs-targeting]). Versi subsistem yang di-link adalah 6.0 pada x64 dan
  x86 dan 6.2 pada arm64, dan Windows pada arm64 dimulai dari Windows 10 apa pun pengaturannya.

Windows Vista dan Server 2008 berada di antaranya: biner akan termuat, tetapi
toolchain tidak mendukungnya, penginstal tidak akan berjalan di sana, dan
7-ZSTar tidak diuji di sana.

**Linux hanya didukung sebagai build baris perintah; macOS tidak didukung.**
Fork ini membangun `7zz` native (program konsol `Alone2`) dengan gcc melalui
makefile miliknya sendiri, yang menyertakan makefile upstream dan tidak mengubah satu pun darinya:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Build ini hanya pernah dibangun dan diuji pada Ubuntu 24.04 dengan gcc 13.3 (x86-64): build
bebas peringatan dengan flag upstream, smoke test 77 pemeriksaan lulus,
dan 25 vektor interop buatan Windows serta 37 buatan Linux memberi
hasil yang sama seperti di Windows. Dua file milik fork yang disentuh oleh port ini tetap
dapat dibangun tanpa perubahan di Windows (build x64 bersih, smoke test, dan pembacaan ulang interop
semuanya lulus). Tidak ada GUI. Target Linux upstream lainnya (`7za`, `7zr`, `7z.so`)
tidak didukung: daftar objek gcc-nya tidak memuat apa yang dibutuhkan perubahan fork
pada handler upstream, sehingga diperkirakan gagal di-link. Arsitektur, distribusi,
dan compiler lain belum diverifikasi, dan macOS belum pernah dibangun, sehingga tidak ada
`MACOSX_DEPLOYMENT_TARGET` yang bisa disebutkan. Langkah build, pengujian, dan batasan yang diketahui ada di
`build/linux/README.md`; interoperabilitas dengan alat Linux ada di `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Paket tanpa tanda tangan, SmartScreen, dan Kontrol Aplikasi Pintar

**Penginstal dan program dalam rilis 7-ZSTar tidak ditandatangani kodenya oleh
otoritas sertifikat**, dan proyek ini tidak memiliki sertifikat penandatanganan kode.
Karena itu Windows tidak dapat mengetahui siapa penerbit file tersebut, dan saat Anda menjalankan
`.msi`, atau program dari `.zip`, untuk pertama kali, SmartScreen pertahanan Microsoft
dapat menghentikannya dengan peringatan. Dokumentasi pengembang Microsoft
mencantumkan "No signature" sebagai salah satu kasus yang menampilkan peringatan berjudul
"Windows protected your PC" ("Windows melindungi PC Anda"), yang mengharuskan pengguna memilih "Run anyway"
("Tetap jalankan") sebelum aplikasi berjalan ([Microsoft][smartscreen-rep]). Kebijakan perusahaan dapat
menghapus pilihan itu sepenuhnya; di PC seperti itu, tanyakan kepada pihak yang mengelolanya.

Satu-satunya hal dalam rilis yang *ditandatangani* adalah paket kecil yang menempatkan
7-ZSTar di tingkat pertama menu klik kanan Windows 11, di dalam
`.msi` untuk semua pengguna. Sertifikatnya ditandatangani sendiri (self-signed) dan dibuat saat paket
itu dibangun, jadi itu bukan tanda tangan otoritas sertifikat dan tidak menyatakan apa pun tentang
siapa yang membangun paket tersebut; lihat [menu klik kanan Windows 11](#menu-klik-kanan-windows-11)
untuk fungsinya dan cara menolaknya.

Peringatan itu bukan bukti bahwa sebuah file buruk, dan ketiadaannya bukan bukti
bahwa sebuah file baik. Yang bisa Anda periksa sendiri adalah apakah salinan Anda persis
sama dengan yang dipublikasikan di halaman rilis. Setiap rilis menyertakan file bernama
`SHA256SUMS`: satu baris per paket, berisi hash SHA-256 diikuti nama file.

1. Unduh paket dan `SHA256SUMS` dari halaman rilis yang sama, ke folder
   yang sama.
2. Buka PowerShell di folder itu lalu bandingkan. Ganti namanya dengan file
   yang Anda unduh:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` berarti kedua hash identik. Jika Anda ingin melihatnya sendiri, jalankan
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` dan cari nama file yang sama
   di `SHA256SUMS`; perbandingannya tidak membedakan huruf besar dan kecil.
3. Jika hasilnya `False`, atau nama file tidak ada di `SHA256SUMS`, jangan jalankan:
   hapus file itu dan unduh lagi. Jika masih tidak cocok, mohon
   laporkan seperti dijelaskan di [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` hanya mencakup file yang diunggah ke rilis tersebut. Membangun tag yang sama
sendiri menghasilkan hash yang berbeda (paket menu klik kanan ditandatangani
dengan sertifikat baru pada setiap build), dan kode sumber dipublikasikan pada
setiap rilis jika Anda lebih suka membangunnya sendiri: lihat [build/README.md](../../build/README.md).

Setelah hash cocok dan Anda yakin dengan asal file:

- **`.msi`** - jalankan seperti biasa. Jika SmartScreen menghentikannya, pilih opsi untuk
  tetap menjalankannya ("Run anyway" pada Windows berbahasa Inggris; "Tetap jalankan"). Jendela peringatan
  mungkin perlu diperluas dulu: pada mesin Windows 10 yang diuji, jendela itu
  hanya menawarkan tombol untuk tidak menjalankan file ("Jangan jalankan") sampai tautan di bawah pesannya
  ("Informasi lainnya") diklik. `.msi` untuk semua pengguna kemudian meminta persetujuan Administrator seperti
  penginstal lainnya.
- **`.zip`** - ekstrak lalu jalankan `7zFM.exe` atau `7z.exe` dari folder tersebut. Program
  di dalamnya juga tidak ditandatangani, sehingga Windows mungkin menampilkan peringatan yang sama
  saat Anda menjalankan masing-masing untuk pertama kali.

SmartScreen memperingatkan berdasarkan seberapa dikenal sebuah file, bukan hanya berdasarkan tanda tangan; file
yang diunduh oleh sedikit orang dapat memicunya meskipun sudah ditandatangani. Tidak ada
yang di sini mengubah hal itu, dan tidak ada langkah di atas yang mematikan SmartScreen.

### Kontrol Aplikasi Pintar di Windows 11

Sebagian PC Windows 11 menyalakan perlindungan yang lebih ketat bernama **Kontrol Aplikasi Pintar**.
Saat aktif, Windows memblokir file tanpa tanda tangan kecuali layanan cloud Microsoft
dapat menjaminnya, dan rilis baru biasanya belum memiliki catatan seperti itu
([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Berbeda dari peringatan SmartScreen,
pemblokiran ini tidak memiliki opsi untuk tetap menjalankan file, dan FAQ Microsoft menyatakan
tidak ada cara untuk melewati Kontrol Aplikasi Pintar bagi satu aplikasi tertentu.

Yang terjadi saat 7-ZSTar 26.05.1 dicoba di Windows 11 Pro 25H2 (build
26200.8037) dengan Kontrol Aplikasi Pintar diaktifkan:

- **Penginstal `.msi` diblokir**, baik yang untuk semua pengguna maupun yang per pengguna.
  Pada Windows berbahasa Mandarin Tradisional, Windows Installer menampilkan
  「系統禁用此安裝。請連絡系統管理員。」, dan notifikasi Keamanan Windows menyatakan
  bahwa Kontrol Aplikasi Pintar telah memblokir file itu karena Windows tidak dapat mengetahui siapa
  penerbitnya dan itu bukan aplikasi yang dikenal Windows. Tidak ada opsi untuk
  melanjutkan, dan `msiexec /i ... /qn` mengembalikan error 1625. Pesan itu
  adalah string 1625 milik Windows Installer; pada Windows berbahasa Inggris, string yang sama
  berbunyi "The system administrator has set policies to prevent this
  installation." (dibaca dari sumber daya bahasa Inggris Windows Installer, tidak terlihat di
  layar).
- **Program dari `.zip` berjalan.** `7zFM.exe`, yang diekstrak dari `.zip`
  portabel, berjalan normal dalam pengujian yang sama. Apakah Windows mengizinkan program tanpa tanda tangan
  berjalan adalah penilaian Windows sendiri terhadap file itu, sehingga hasilnya mungkin berbeda di
  PC Anda.
- Tepat setelah Kontrol Aplikasi Pintar diaktifkan, `.msi` bisa diinstal selama beberapa menit
  sebelum mulai diblokir. Penyebabnya tidak ditemukan, jadi keberhasilan
  tepat setelah mengaktifkannya tidak berarti penginstal diizinkan.

Jadi di PC dengan Kontrol Aplikasi Pintar yang aktif, **penginstal tidak dapat diinstal**,
dan memeriksa `SHA256SUMS` tidak mengubahnya. Yang mengubahnya adalah mematikan Kontrol Aplikasi
Pintar di aplikasi Keamanan Windows, di bagian Pengaturan Kontrol Aplikasi Pintar (pada Windows berbahasa Mandarin Tradisional yang diuji: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定).
Dalam pengujian, memilih opsi Nonaktif berlaku seketika tanpa restart, dan penginstal
kemudian berhasil diinstal. Ini adalah pengaturan untuk seluruh PC dan tidak ada yang
di sini meminta Anda mengubahnya: itu keputusan Anda, atau keputusan Administrator Anda pada PC yang dikelola.

Perlu diketahui juga lebih dulu apakah pengaturan itu bisa dihidupkan kembali. FAQ Microsoft
menyatakan pembaruan Windows terbaru memungkinkan Kontrol Aplikasi Pintar diaktifkan lagi
tanpa instalasi Windows yang bersih, jadi pada versi tanpa pembaruan itu, mematikannya
bisa bersifat permanen. Pada build yang diuji di sini, opsi untuk
mengaktifkannya masih ditawarkan setelah dimatikan; itu hasil pengujian, bukan janji
tentang versi Anda.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Menginstal

Tiga paket, semuanya dibangun oleh `installer\Build-Package.ps1` (yang per pengguna
dengan `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Diinstal untuk | setiap akun | akun yang menginstal | - |
| Menu klik kanan File Explorer | ya | ya, hanya menu klasik ([di bawah](#paket-per-pengguna)) | tidak |
| Entri Menu Mulai | ya | ya | tidak |
| Perlu Administrator | ya | tidak | tidak |
| Penghapusan | *Aplikasi terinstal* di Pengaturan | *Aplikasi terinstal* di Pengaturan | hapus folder |

*Aplikasi terinstal* adalah nama di Windows 11. Windows 10 menyebut halaman yang sama *Aplikasi dan Fitur*,
dan di Windows 7 namanya *Programs and Features* (program dan fitur) di Control Panel (panel kontrol).

Gunakan paket yang sesuai dengan Windows itu sendiri: x86 di Windows 32-bit, x64 di
Windows 64-bit, arm64 di Windows pada Arm (paket arm64 sudah dibangun tetapi
belum pernah dijalankan). Ekstensi shell x86 berupa 32-bit dan File Explorer 64-bit tidak dapat
memuatnya, sehingga di Windows 64-bit `-user.msi` x86 tidak memiliki menu klik kanan
sama sekali, dan `.msi` x86 hanya memilikinya di Windows 11 dan hanya untuk akun yang
mendaftarkan paket Windows 11-nya (akun yang menginstal, atau akun yang menjalankan
`-Register`, di bawah).

MSI menginstal ke `Program Files\7-ZSTar` - selalu: berbeda dengan paket per pengguna,
MSI tidak menawarkan pilihan folder, dan mengabaikan `INSTALLFOLDER` di
baris perintah, karena folder itu berisi skrip yang dijalankan penginstal sebagai SYSTEM
dan DLL yang dimuat File Explorer setiap pengguna, dan folder yang dibuat di tempat lain (misalnya di bawah
`C:\`) dapat ditulisi oleh setiap pengguna. MSI mendaftarkan CLSID ekstensi shell miliknya sendiri
dan hive registri `Software\7-ZSTar` miliknya sendiri, dan menamai setiap kunci
menu konteks `7-ZSTar` - jadi tidak bertabrakan dengan dan tidak menghapus milik 7-Zip resmi.
Lihat [installer/GUIDS.md](../../installer/GUIDS.md).

MSI menjalankan wizard instalasi yang normal - welcome, licence, setup type, optional feature tree, finish
(sambutan, lisensi, jenis penyiapan, pohon fitur opsional, selesai) - dan penginstalan senyap tetap bekerja tanpa perubahan
(`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), karena msiexec melewati
seluruh urutan UI dalam mode senyap. Wizard hanya berbahasa Inggris, juga pada
Windows yang diatur ke bahasa lain (terlihat pada Windows 10 berbahasa Mandarin Tradisional; `.msi`
dibangun tanpa bahasa lain), dan halaman selesainya memiliki *Launch
7-ZSTar File Manager* yang tercentang secara default.

### Menu klik kanan Windows 11

Di Windows 11, entri 7-ZSTar berada di menu tingkat pertama, tidak terkubur di bawah *Tampilkan opsi lainnya*
tempat 7-Zip resmi dan WinRAR masih berada. Windows 11 hanya menampilkan
ekstensi shell di sana jika disertai identitas paket, sehingga MSI menyertakan
paket MSIX kecil yang hanya berisi identitas di samping program dan mendaftarkannya saat
instalasi. Registrasi klasik tetap dipertahankan. Registrasi itulah yang menempatkan entri
di menu klik kanan pada Windows 10 dan Windows 7, yang menunya hanya satu
tingkat tanpa *Tampilkan opsi lainnya*, dan yang membuatnya tetap berfungsi bagi siapa pun
yang telah mengembalikan menu konteks lama.

Paket itu ditandatangani dengan **sertifikat self-signed**, dan penginstal
menempatkannya di `LocalMachine\TrustedPeople` - Windows tidak akan men-deploy paket
yang tanda tangannya tidak dapat dikaitkan ke sesuatu yang tepercaya. Uninstal menghapus
sertifikat bersama paketnya. Di Windows 10 dan Windows 7 penginstal
tidak melakukan keduanya: tidak menambahkan sertifikat dan tidak mendaftarkan paket, dan
registrasi klasik saja yang menyediakan menunya.

Jika Anda tidak ingin memercayai sertifikat self-signed, tolak bagian itu saja
dan pertahankan yang lainnya:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Anda kemudian hanya mendapatkan menu klasik, sehingga di Windows 11 entri 7-ZSTar berada di
menu klik kanan di bawah *Tampilkan opsi lainnya*. Untuk mengaktifkan entri tingkat pertama
kemudian, atau membatalkannya setelah instalasi normal:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Memercayai sertifikat itu berarti Windows juga akan menerima **paket lain apa pun**
yang ditandatangani dengan kunci yang sama tanpa peringatan. Sertifikat itu hanya digunakan untuk
satu paket ini, dan uninstal mencabutnya kembali, tetapi itulah yang Anda setujui -
`SPARSE=0` di atas adalah cara untuk menolaknya.

Registrasi paket bersifat per pengguna, dan penginstal hanya menjalankannya untuk siapa pun yang
menginstal. Dua konsekuensinya:

- Akun kedua di mesin yang sama hanya mendapatkan menu klasik, sampai akun itu
  menjalankan skrip yang sama dengan `-Register`.
- Uninstal hanya membatalkan registrasi untuk yang menjalankan uninstal. Jika orang lain
  yang mendaftarkannya, registrasi mereka tetap ada setelah uninstal dan menunjuk ke
  folder yang sudah tidak ada; akun itu membersihkannya dengan
  `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Keterbatasan yang diketahui: menu tingkat pertama hanya terdaftar jika instalasi
berjalan dalam sesi interaktif yang sudah masuk (sign-in).** Menginstal `.msi` untuk semua pengguna
dari sesi jarak jauh atau non-interaktif - lewat SSH, atau penerapan senyap dari
alat manajemen - tetap melaporkan berhasil, tetapi paket Windows 11 tidak
terdaftar, sehingga hanya menu klasik di bawah *Tampilkan opsi lainnya* yang muncul. Dalam
pengujian, `msiexec /i ... /qn` dari sesi SSH (sesi 0) selesai dengan kode 0
sementara `Setup-ShellIntegration.ps1` melaporkan `registration failed: 0x80070005`
(akses ditolak); `.msi` yang sama yang diinstal dari sesi konsol Administrator
terdaftar secara normal.

`-Status` mencetak apa yang sudah dan belum terpasang.

### Paket per pengguna

`7-ZSTar-<version>-<arch>-user.msi` menginstal hanya untuk akun saat ini, ke
`%LOCALAPPDATA%\Programs\7-ZSTar`, tanpa prompt Kontrol Akun Pengguna (UAC). Semua yang didaftarkannya
berada di bawah `HKCU`; paket ini tidak menulis apa pun ke `HKLM` (selain pembukuan milik Windows Installer
sendiri). Hal yang tidak dilakukannya seperti paket per mesin:

- **Tidak ada menu tingkat pertama Windows 11.** Di Windows 11, 7-ZSTar berada di
  menu klik kanan di bawah *Tampilkan opsi lainnya*. Entri tingkat pertama memerlukan
  sertifikat self-signed yang dipercaya di seluruh mesin, yang membutuhkan Administrator:
  diukur di Windows 11, sertifikat di `CurrentUser\TrustedPeople` tidak
  cukup agar Windows men-deploy paket tersebut. Jadi paket per pengguna
  tidak menyertakannya.
- **Salah satu dari dua per mesin.** Setiap paket menolak diinstal selama
  yang lain terinstal; uninstal salah satunya sebelum menginstal yang lain. Paket
  per mesin hanya dapat melihat salinan per pengguna milik akun yang menjalankannya,
  sehingga instalasi per pengguna milik akun lain tidak terdeteksi.
- **Group policy (kebijakan grup) dapat menyembunyikan menunya.** Jika `EnforceShellExtensionSecurity`
  diatur, File Explorer hanya memuat ekstensi shell yang tercantum di bawah kunci
  *Approved* tingkat mesin, yang tidak dapat ditulis oleh instalasi per pengguna, sehingga menu
  klik kanan tidak muncul. Gunakan paket per mesin di sana.
- **Mengosongkan sebuah format di Peralatan > Pilihan > Sistem juga menghapus tawaran 7-ZSTar
  untuk format itu.** Saat Anda mengosongkan sebuah format di sana (klik selnya sampai kosong,
  lalu Oke), pengelola file menghapus seluruh kunci
  `HKCU\Software\Classes\.<ext>` dan `7-ZSTar.<ext>` - dan pada instalasi per pengguna kunci-kunci itu
  juga menyimpan apa yang didaftarkan paket untuk Pengaturan > Aplikasi > Aplikasi default
  dan daftar *Buka dengan*. 7-ZSTar kemudian hilang dari
  *Buka dengan* untuk format itu, dan Aplikasi default menampilkan entri kosong untuknya.
  Memperbaiki instalasi mengembalikannya (jalankan `.msi` lagi dan pilih
  *Repair*). Lebih baik, tetapkan jenis file di Aplikasi default, bukan di pengelola
  file. Paket per mesin memiliki titik lemah yang sama di satu tempat,
  dijelaskan di bawah pada bagian asosiasi file.

### Asosiasi file, dan dampak uninstal terhadapnya

**Atur di Pengaturan > Aplikasi > Aplikasi default.** Di Windows 11, ketik 7-ZSTar
di sana dan setiap format yang dapat dibukanya akan terdaftar untuk ditetapkan. Di Windows 10,
7-ZSTar terdaftar di bawah *Set defaults by app* (atur default menurut aplikasi) pada halaman itu, tempat *Manage* (kelola)
menampilkan formatnya. Windows 7 tidak memiliki aplikasi Pengaturan: 7-ZSTar terdaftar di bawah
Control Panel > Default Programs > *Set your default programs* (artinya: Program Default > Atur program default), yang menjadi pengganti
*Aplikasi default* dalam panduan ini di sana. Penetapan format dari kedua
halaman itu belum diuji. Penginstal mendaftarkan 7-ZSTar sebagai aplikasi Program Default
- ProgID per format dengan ikon dan perintah bukanya, entri di daftar
*Buka dengan* setiap ekstensi, dan blok Capabilities yang dibaca Windows - tetapi
dengan sengaja tidak mengklaim jenis file apa pun: program mana yang membuka arsip Anda adalah
keputusan Anda, dan itulah yang menjaga 7-ZSTar dan 7-Zip resmi tidak saling mengganggu.
Windows tetap dapat mengarahkan sebuah format ke 7-ZSTar dengan sendirinya
jika tidak ada program lain yang menawarkan diri membukanya: pada mesin Windows 10 dan Windows 7
yang diuji, ketika tidak ada program lain yang mendaftarkan `.7z`, file `.7z` menampilkan
ikon 7-ZSTar dan terbuka di dalamnya saat diklik dua kali, tanpa Windows menanyakan program
mana yang dipakai.

**Peralatan > Pilihan > Sistem di pengelola file sebagian besar tidak berfungsi di
Windows 11**, dan itu aturan Windows, bukan bug di sini. Pengaturan itu menulis
ProgID `7-ZSTar.<ext>` ke `HKCU\Software\Classes`, dan untuk ekstensi apa pun yang
sudah dikenal mesin - setiap format arsip termasuk - Windows 11 mengabaikannya:
`AssocQueryString` menjawab `Unknown` dan File Explorer menggambar ikon generik kosong.
Yang dihormatinya adalah kunci `UserChoice` yang dicap dengan hash yang hanya dapat dihitung
Windows, itulah sebabnya UI Pengaturan adalah satu-satunya jalan di sana. Tidak ada
aplikasi yang bisa menulisnya: bukan 7-ZSTar, bukan 7-Zip, bukan penginstal mana pun. Windows
10 dan Windows 7 berperilaku berbeda dalam pengujian: setelah `.7z` dan `.zst` diatur
di pengelola file, tanpa program lain yang dipilih untuk keduanya, `AssocQueryString`
mengembalikan `7zFM.exe` untuk keduanya.

**Mengosongkan sebuah format di kolom *Semua pengguna* menghapus registrasi milik
paket per mesin untuk format itu.** Kolom itu menulis
`HKLM\Software\Classes`, tempat paket per mesin menyimpan ProgID dan
entri *Buka dengan* yang diiklankannya, dan mengosongkan sebuah format di sana (yang mengharuskan
pengelola file dibuka lewat "Jalankan sebagai administrator") menghapus kunci-kunci itu seluruhnya - untuk setiap
akun. Perbaikan (repair) memulihkan kunci yang sama untuk paket per pengguna; untuk paket
yang ini belum diukur.

**Ikon yang tetap kosong setelah mengubah apa pun** mungkin juga disebabkan cache
ikon File Explorer, yang tidak menyadari bahwa DLL yang sudah di-cache telah
diganti; `ie4uinit.exe -show` tidak andal membersihkannya. Tutup File Explorer,
hapus `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, lalu jalankan
lagi.

**Uninstal menghapus asosiasi yang dapat dijangkaunya** - ProgID `7-ZSTar.*`
milik siapa pun yang melakukan uninstal, dan hanya jenis file yang masih
menunjuk ke ProgID itu, sehingga format yang sementara itu diserahkan ke program lain dibiarkan
apa adanya. Uninstal paket per mesin juga membiarkan ProgID yang
membuka salinan 7-ZSTar di tempat lain yang masih ada - salinan portabel dari
`.zip`, yang diatur lewat **Peralatan > Pilihan > Sistem** milik salinan itu sendiri. Paket
per pengguna tidak bisa: ProgID-nya adalah kunci `HKCU` yang sama (lihat *Paket
per pengguna* di atas), dan uninstalnya menghapusnya siapa pun yang menulisnya
terakhir. Membiarkannya akan membuat jenis file itu menunjuk ke ProgID yang ikon dan
perintahnya adalah executable yang sudah dihapus, yang berarti ikon kosong dan error saat
diklik dua kali. Asosiasi akun lain berada di luar jangkauan; mereka dapat membersihkan
milik mereka sendiri dengan `Setup-ShellIntegration.ps1 -RemoveAssociations` sebelum
programnya dihapus. `msiexec /x ... KEEPASSOC=1` melewati langkah ini, dan upgrade tidak pernah
melakukannya.

**Keterbatasan yang diketahui: akun lain mempertahankan asosiasi yang mereka atur sendiri.**
Uninstal paket per mesin hanya membersihkan apa yang diatur oleh akun yang menjalankan
uninstal di kolomnya sendiri (kolom yang berjudul nama akun) di bawah
**Peralatan > Pilihan > Sistem** di pengelola file. Akun lain yang mengatur
asosiasi di sana mempertahankannya, menunjuk ke program yang sudah dihapus, sehingga
mengklik dua kali file `.7z` membuat Windows menanyakan program mana yang dipakai. Setiap akun
sebaiknya membersihkan miliknya **sebelum** uninstal, dengan

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

yang hanya menghapus entri milik 7-ZSTar, atau sesudahnya menetapkan kembali jenis-jenis file
di Pengaturan > Aplikasi > Aplikasi default. Melakukannya di pengelola file berarti
mengklik setiap sel di kolomnya sendiri yang menampilkan 7-ZSTar sampai
kosong, lalu Oke; jangan memilih semua baris dan menekan "+", yang menerapkan satu status ke setiap
baris yang dipilih sehingga juga mengosongkan format milik program lain, seperti
7-Zip resmi.

Asosiasi yang diatur di kolom **Semua pengguna** sama sekali tidak disentuh oleh pembersihan
saat uninstal, dan dibiarkan mengarahkan setiap akun ke program yang sudah dihapus.
Administrator yang mengatur salah satunya sebaiknya mengosongkan sel-sel itu, dari pengelola file yang dibuka
lewat "Jalankan sebagai administrator", lalu Oke, sebelum uninstal; `-RemoveAssociations` tidak
menjangkau kolom ini. Mengosongkannya tepat sebelum uninstal tidak berbahaya
meskipun itu menghapus registrasi milik paket di sana (di atas), karena
uninstal akan menghapusnya juga. Paket per pengguna tidak memiliki masalah
akun lain, dan 7-Zip resmi berperilaku sama.

## Bahasa

Setiap paket membawa terjemahan dari upstream, lebih dari 90 bahasa. Pilih satu di **Peralatan > Pilihan > Bahasa**;
MSI juga memungkinkan Anda tidak menyertakannya pada jenis penyiapan *Custom*. 7-ZSTar mencoba mengikuti bahasa sistem
saat pertama kali dijalankan, tetapi deteksi itu menyerah dan tetap berbahasa Inggris ketika "language for
non-Unicode programs" (bahasa untuk program non-Unicode) di Windows dan pengaturan Format regional
tidak sama - memilih bahasa secara manual selalu berhasil.

String yang ditambahkan 7-ZSTar sendiri - kolom level dan kamus zstd, nama format arsip
yang baru - tidak memiliki terjemahan upstream dan tetap berbahasa Inggris. Pengecualiannya adalah
tombol **Donasi** dan **Situs web** di dialog Mengenai 7-ZSTar: 67 dari 92
bahasa memiliki terjemahan untuk masing-masing, dan 25 bahasa lainnya menampilkan bahasa Inggris
(`Lang/UPSTREAM.md` mencantumkannya).
Terjemahan diambil dari upstream dan disertakan apa adanya, bukan ditulis di sini: lihat [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
