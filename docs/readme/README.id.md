<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · [Tiếng Việt](README.vi.md) · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · **Bahasa Indonesia** · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Jika isi dokumen ini berbeda dengan versi bahasa Inggris, yang berlaku adalah versi bahasa Inggris.*

**Fork 7-Zip yang lebih ramah bagi pengguna Windows 11 masa kini: ada di tingkat pertama menu klik kanan, mendukung kompresi zstd, dan membuat tar.zst sekali jalan.**

[Unduh](https://github.com/7zStar/7-ZSTar/releases/latest) · [Situs web](https://www.7zstar.com) · [Catatan perubahan](../../CHANGELOG.md)

## Mengapa 7-ZSTar

- **Tak perlu lagi “Tampilkan opsi lainnya”.** Di Windows 11, 7-ZSTar langsung ada di tingkat pertama menu klik kanan.
- **tar.zst dalam satu langkah.** Mengompresi folder menjadi .tar.zst, atau mengekstraknya, cukup satu langkah, tanpa meninggalkan file .tar di disk. 7-Zip resmi tidak bisa membuat .tar.zst, dan mengekstraknya dalam dua langkah, lewat .tar.
- **Sekitar 10× lebih cepat dari 7z.** Pada folder proyek nyata, tar.zst selesai dikompresi 10 sampai 18 kali lebih cepat.

## Kecepatan

| Folder | File | Ukuran asli | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 dtk / 76.7 MB | 38.4 dtk / 51.8 MB | **3.8 dtk** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 dtk / 107.8 MB | 54.8 dtk / 65.7 MB | **3.6 dtk** / 83.4 MB |
| Python `.venv` (biner besar) | 11,654 | 671 MB | 25.5 dtk / 249.5 MB | 100.8 dtk / 167.2 MB | **5.6 dtk** / 210.9 MB |

Hasil tar.zst 15 sampai 23% lebih kecil daripada zip, dan tidak lebih lambat. 7z tetap menghasilkan file terkecil (tar.zst 15 sampai 27% lebih besar), tetapi waktunya jauh lebih lama. Untuk ekstraksi, ketiga format butuh waktu yang kurang lebih sama.

Ketiganya memakai pengaturan bawaan; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, median dari 3 kali uji, 2026-11.

## Format

- **Kompres dalam satu langkah:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Ekstrak dalam satu langkah:** semua di atas, ditambah tar.lzma dan tar.Z
- **Codec tambahan:** zstd, brotli, lz4, lz5, dan lizard (bisa dipakai sendiri atau di dalam .7z), ditambah fast-lzma2, encoder LZMA2 alternatif
- Semua format yang bisa ditangani 7-Zip resmi tetap berfungsi.

## Unduh

Kebanyakan orang cukup mengambil `.msi` x64 untuk semua pengguna dari [Releases](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` untuk semua pengguna | `-user.msi` hanya untuk Anda | `.zip` portabel |
|---|---|---|---|
| Memerlukan hak Administrator | Ya | Tidak | Tidak |
| Menu klik kanan | Tingkat pertama di Windows 11 | Menu klasik (di bawah “Tampilkan opsi lainnya” di Windows 11) | Tidak ada |
| Entri di Menu Mulai | Ya | Ya | Tidak |

Masing-masing juga tersedia untuk x86 dan arm64; pilih yang sesuai dengan Windows Anda. Di Windows 64-bit, paket x86 mungkin tidak punya menu klik kanan, dan build arm64 belum dicoba di perangkat keras sungguhan. 7-ZSTar bisa dipasang berdampingan dengan 7-Zip resmi tanpa memengaruhinya.

**Windows mungkin memberi peringatan saat pertama kali.** File-nya tidak ditandatangani kode, jadi SmartScreen bisa menghentikannya (“Windows melindungi PC Anda”; mungkin Anda perlu membuka peringatan itu dulu untuk melihat *Tetap jalankan*), dan di Windows 11 yang Kontrol Aplikasi Pintar-nya aktif, `.msi` langsung diblokir. Setiap rilis menyertakan file `SHA256SUMS` untuk memeriksa unduhan Anda. [Panduan instalasi](../install/INSTALL.id.md#paket-tanpa-tanda-tangan-smartscreen-dan-kontrol-aplikasi-pintar) menjelaskan caranya, dan apa yang perlu dilakukan terkait Kontrol Aplikasi Pintar.

**Tentang menu tingkat pertama:** di Windows 11, `.msi` untuk semua pengguna menambahkan paket kecil yang ditandatangani dengan sertifikat yang dibuat sendiri (self-signed) dan memercayai sertifikat itu; itulah yang disyaratkan Windows agar bisa tampil di tingkat pertama. Saat di-uninstal, keduanya ikut dihapus. Jika Anda tidak menginginkannya, instal dengan `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Paket itu didaftarkan untuk akun yang menjalankan penginstal; akun lain mendaftarkannya sendiri-sendiri.

Asosiasi file, uninstal, dan paket per pengguna dijelaskan di [panduan instalasi](../install/INSTALL.id.md).

## Baris perintah

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Di PowerShell, beri tanda kutip pada switch-nya: `7z a "-ttar.zst" backup.tar.zst docs`. Tanpa tanda kutip, PowerShell memecahnya jadi dua dan hasilnya sebuah file bernama `.zst`. Prompt Perintah (cmd) tidak memerlukan tanda kutip.

## Perlu diketahui

- **Mematikan “Integrasikan 7-ZSTar ke cangkang menu konteks”** (pengelola file, **Peralatan > Pilihan > 7-ZSTar**) menghapus entri klik kanan, sama seperti di 7-Zip resmi. Dengan paket untuk semua pengguna, nyalakan kembali dengan menjalankan pengelola file lewat "Jalankan sebagai administrator". Dengan paket per pengguna hal itu tidak bisa dilakukan (“Access is denied.”); jalankan `.msi` itu lagi dan pilih *Repair* (perbaiki).
- **Instalasi senyap atau jarak jauh di Windows 11** (lewat SSH, atau dari alat deployment) berhasil, tetapi entri tingkat pertamanya tidak terdaftar, sehingga 7-ZSTar hanya muncul di bawah “Tampilkan opsi lainnya”. [Selengkapnya di panduan instalasi](../install/INSTALL.id.md#menu-klik-kanan-windows-11).
- **Mengekstrak tar.br, tar.lz4, tar.lz5, tar.liz, atau tar.Z** bagi Anda tetap satu langkah, tetapi prosesnya melewati file sementara yang dihapus setelahnya.

## Persyaratan sistem

Windows 7 / Server 2008 R2 atau lebih baru (x64, x86), atau Windows 10 atau lebih baru di arm64. Tidak ada lagi yang perlu diinstal. Sudah diuji di Windows 7 SP1 64-bit (dengan pembaruan lanjutan terpasang), Windows 10, dan Windows 11; [apa saja yang diuji](../install/INSTALL.id.md#persyaratan-sistem). Di Linux tersedia build baris perintah yang harus Anda kompilasi sendiri; macOS tidak didukung.

## Dokumentasi

**Bantuan > Konten** dan F1 membuka `7-zip.chm`, file bantuan 7-Zip resmi. Isinya menyebut “7-Zip” di mana-mana dan tidak membahas apa yang ditambahkan 7-ZSTar; halaman ini dan [catatan perubahan](../../CHANGELOG.md) yang membahasnya. Jika file bantuan tidak ada, entri yang sama akan membuka bagian ini secara online.

Untuk membangun 7-ZSTar sendiri, lihat [build/README.md](../../build/README.md); sebelum menggabungkan rilis upstream yang baru, baca [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Donasi

7-ZSTar gratis dipakai, baik Anda berdonasi maupun tidak. Jika aplikasi ini sudah menghemat waktu Anda dan Anda ingin berterima kasih, Anda bisa mengirim kripto ke alamat di bawah. Dana itu masuk ke saya, DraftingDreamer, untuk biaya pengembangan saya sendiri, dan tidak membeli fitur, bantuan, atau janji apa pun tentang kelanjutannya.

Token apa pun di Ethereum atau Polygon diterima: ETH, POL, USDT, USDC, atau lainnya. Alamatnya sama di kedua jaringan.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Kode QR alamat donasi">

- Hanya transfer di Ethereum (ERC20) dan Polygon yang diterima. Jika bisa memakai keduanya, Polygon biasanya berbiaya lebih rendah.
- Ini satu-satunya alamat resmi, dan saya tidak akan pernah meminta Anda mengirim ke alamat lain.
- Transfer tidak bisa dibatalkan, jadi tidak bisa dikembalikan.

Memberi bintang pada 7-ZSTar di GitHub atau menceritakannya ke teman juga membantu.

## Lisensi

LGPL v3, lihat [LICENSE](../../LICENSE). Beberapa bagian memiliki ketentuan lain: dekompresi RAR terkena pembatasan unRAR, sehingga build dengan dukungan RAR tidak sepenuhnya LGPL v3. Daftar lengkapnya ada di [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), dan pemberitahuan hak ciptanya ada di [NOTICE](../../NOTICE).

Terima kasih kepada semua orang yang telah meluangkan waktu untuk 7-Zip, algoritma kompresi, dan dunia sumber terbuka pada umumnya. 7-ZSTar tidak akan ada tanpa kalian.
