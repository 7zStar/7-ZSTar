<!-- synced-with: README.md @ 8d159f1 -->
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · **Tiếng Việt** · [Русский](README.ru.md) · [한국어](README.ko.md) · [Italiano](README.it.md) · [Polski](README.pl.md) · [Türkçe](README.tr.md) · [Nederlands](README.nl.md) · [Українська](README.uk.md) · [Bahasa Indonesia](README.id.md) · [ไทย](README.th.md) · [Čeština](README.cs.md) · [Magyar](README.hu.md) · [Română](README.ro.md) · [Svenska](README.sv.md) · [Ελληνικά](README.el.md) · [हिन्दी](README.hi.md) · [العربية](README.ar.md) · [فارسی](README.fa.md) · [עברית](README.he.md) · [Esperanto](README.eo.md)

*Nếu có điểm nào khác với bản tiếng Anh, hãy lấy bản tiếng Anh làm chuẩn.*

**Bản fork của 7-Zip thân thiện hơn với người dùng Windows 11 hiện đại: menu chuột phải ở cấp đầu tiên, nén zstd và tar.zst trong một lượt.**

[Tải xuống](https://github.com/7zStar/7-ZSTar/releases/latest) · [Trang web](https://www.7zstar.com) · [Nhật ký thay đổi](../../CHANGELOG.md)

## Vì sao chọn 7-ZSTar

- **Không còn phải bấm “Xem thêm tùy chọn”.** Trên Windows 11, 7-ZSTar nằm ngay ở cấp đầu tiên của menu chuột phải.
- **tar.zst trong một bước.** Nén một thư mục thành .tar.zst, hay giải nén một tệp .tar.zst, chỉ cần một bước, không để lại tệp .tar nào trên đĩa. 7-Zip chính thức không tạo được .tar.zst, còn giải nén thì phải qua hai bước, đi qua một tệp .tar.
- **Nhanh gấp khoảng 10 lần 7z.** Trên các thư mục dự án thực tế, tar.zst nén nhanh hơn từ 10 đến 18 lần.

## Tốc độ

| Thư mục | Số tệp | Dung lượng gốc | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13,371 | 207 MB | 4.1 s / 76.7 MB | 38.4 s / 51.8 MB | **3.8 s** / 59.7 MB |
| Python `.venv` | 9,795 | 346 MB | 6.6 s / 107.8 MB | 54.8 s / 65.7 MB | **3.6 s** / 83.4 MB |
| Python `.venv` (tệp nhị phân lớn) | 11,654 | 671 MB | 25.5 s / 249.5 MB | 100.8 s / 167.2 MB | **5.6 s** / 210.9 MB |

tar.zst nhỏ hơn zip từ 15 đến 23% mà không chậm hơn. 7z vẫn tạo ra tệp nhỏ nhất (tar.zst lớn hơn từ 15 đến 27%), nhưng mất nhiều thời gian hơn hẳn. Khi giải nén, cả ba mất thời gian xấp xỉ nhau.

Cả ba đều dùng cài đặt mặc định; 7-ZSTar 26.05.1 x64, Intel Core Ultra 7 155H, NVMe SSD, trung vị của 3 lượt chạy, 2026-11.

## Định dạng

- **Nén trong một bước:** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Giải nén trong một bước:** tất cả các định dạng trên, cộng thêm tar.lzma và tar.Z
- **Codec bổ sung:** zstd, brotli, lz4, lz5 và lizard (dùng riêng hoặc bên trong .7z), cộng thêm fast-lzma2, một bộ mã hóa LZMA2 thay thế
- Mọi định dạng mà 7-Zip chính thức xử lý được vẫn dùng bình thường.

## Tải xuống

Hầu hết mọi người chỉ cần tệp `.msi` x64 cho mọi người dùng trên trang [Bản phát hành](https://github.com/7zStar/7-ZSTar/releases/latest).

| | `.msi` cho mọi người dùng | Riêng bạn `-user.msi` | `.zip` không cần cài đặt |
|---|---|---|---|
| Cần quyền quản trị viên | Có | Không | Không |
| Menu chuột phải | Cấp đầu tiên trên Windows 11 | Menu cổ điển (trên Windows 11 nằm trong “Xem thêm tùy chọn”) | Không có |
| Mục trong Menu Bắt đầu | Có | Có | Không |

Mỗi loại cũng có bản x86 và arm64; hãy chọn bản khớp với Windows của bạn. Trên Windows 64-bit, các gói x86 có thể không có menu chuột phải, và các bản arm64 chưa được thử trên phần cứng thật. 7-ZSTar cài song song với 7-Zip chính thức mà không ảnh hưởng đến nó.

**Lần đầu, Windows có thể cảnh báo.** Các tệp này chưa được ký mã (code-sign), nên SmartScreen có thể chặn chúng (“Windows bảo vệ máy tính của bạn”; có thể bạn phải mở rộng cảnh báo để thấy nút *Chạy dù thế nào đi nữa*), và trên Windows 11 khi Kiểm soát Ứng dụng Thông minh đang bật, tệp `.msi` bị chặn hẳn. Mỗi bản phát hành đều có tệp `SHA256SUMS` để bạn đối chiếu tệp đã tải. [Hướng dẫn cài đặt](../install/INSTALL.vi.md#gói-chưa-ký-smartscreen-và-kiểm-soát-ứng-dụng-thông-minh) giải thích cách làm, và cách xử lý khi gặp Kiểm soát Ứng dụng Thông minh.

**Về menu cấp đầu tiên:** trên Windows 11, `.msi` cho mọi người dùng thêm một gói nhỏ được ký bằng chứng chỉ tự ký và tin cậy chứng chỉ đó; đó là điều Windows yêu cầu để lên cấp đầu tiên. Gỡ cài đặt sẽ xóa cả hai. Nếu bạn không muốn vậy, hãy cài bằng `msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0`. Gói được đăng ký cho tài khoản chạy trình cài đặt; các tài khoản khác phải đăng ký riêng.

Liên kết tệp, cách gỡ cài đặt và gói riêng bạn được trình bày trong [hướng dẫn cài đặt](../install/INSTALL.vi.md).

## Dòng lệnh

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Trong PowerShell, hãy đặt tham số trong dấu ngoặc kép: `7z a "-ttar.zst" backup.tar.zst docs`. Nếu không có dấu ngoặc kép, PowerShell sẽ tách nó làm hai và bạn nhận được một tệp tên là `.zst`. Dấu nhắc Lệnh (cmd) không cần dấu ngoặc kép.

## Cần biết

- **Tắt “Tích hợp 7-ZSTar vào menu ngữ cảnh”** (trình quản lý tệp, **Công cụ > Tùy chọn > 7-ZSTar**) sẽ xóa mục trong menu chuột phải, giống như 7-Zip chính thức. Với gói cho mọi người dùng, bật lại bằng cách chạy trình quản lý tệp với quyền quản trị viên. Với gói riêng bạn thì không được (“Access is denied.”); hãy chạy lại tệp `.msi` và chọn *Repair* (sửa chữa).
- **Cài đặt im lặng hoặc từ xa trên Windows 11** (qua SSH, hoặc từ một công cụ triển khai) vẫn thành công, nhưng mục ở cấp đầu tiên không được đăng ký, nên 7-ZSTar chỉ xuất hiện trong “Xem thêm tùy chọn”. [Xem thêm trong hướng dẫn cài đặt](../install/INSTALL.vi.md#menu-chuột-phải-của-windows-11).
- **Giải nén tar.br, tar.lz4, tar.lz5, tar.liz hoặc tar.Z** với bạn vẫn là một bước, nhưng phải đi qua một tệp tạm và tệp này được xóa sau đó.

## Yêu cầu hệ thống

Windows 7 / Server 2008 R2 trở lên (x64, x86), hoặc Windows 10 trở lên trên arm64. Không cần cài thêm gì khác. Đã thử trên Windows 7 SP1 64-bit (có cài các bản cập nhật sau đó), Windows 10 và Windows 11; [những gì đã được thử](../install/INSTALL.vi.md#yêu-cầu-hệ-thống). Trên Linux có bản dòng lệnh để bạn tự biên dịch; macOS không được hỗ trợ.

## Tài liệu

**Giúp đỡ > Nội dung** và phím F1 mở `7-zip.chm`, tệp trợ giúp của 7-Zip chính thức. Trong đó chỗ nào cũng ghi “7-Zip” và không nói về những gì 7-ZSTar bổ sung; phần đó có trong trang này và trong [nhật ký thay đổi](../../CHANGELOG.md). Nếu thiếu tệp trợ giúp, chính các mục đó sẽ mở phần này trên mạng.

Để tự biên dịch 7-ZSTar, xem [build/README.md](../../build/README.md); trước khi hợp nhất một bản upstream mới, hãy đọc [MAINTAINING.md](../../MAINTAINING.md).

<a id="donate"></a>

## Ủng hộ

7-ZSTar dùng miễn phí, bạn có ủng hộ hay không cũng vậy. Nếu nó đã giúp bạn tiết kiệm chút thời gian và bạn muốn nói lời cảm ơn, bạn có thể gửi tiền mã hóa đến địa chỉ bên dưới. Khoản này đến tay tôi, DraftingDreamer, để trang trải chi phí phát triển của riêng tôi, và không đổi lấy tính năng, sự hỗ trợ hay bất kỳ cam kết nào về những gì sẽ đến sau này.

Mọi token trên Ethereum hoặc Polygon đều được đón nhận: ETH, POL, USDT, USDC hay loại khác. Địa chỉ giống nhau trên cả hai mạng.

```
0x6c60bFCaDfb3AD63eC6D821baB0E6323361BFD4f
```

<img src="../donate-qr.png" width="200" alt="Mã QR của địa chỉ ủng hộ">

- Chỉ nhận chuyển khoản trên Ethereum (ERC20) và Polygon. Nếu dùng được cả hai, nên chọn Polygon vì phí thường thấp hơn.
- Đây là địa chỉ chính thức duy nhất, và tôi sẽ không bao giờ yêu cầu bạn chuyển sang địa chỉ khác.
- Giao dịch trên chuỗi không thể thu hồi nên không thể hoàn tiền.

Tặng 7-ZSTar một sao (Star) trên GitHub, hoặc giới thiệu cho bạn bè, cũng là cách giúp đỡ.

## Giấy phép

LGPL v3, xem [LICENSE](../../LICENSE). Một số phần đi kèm điều khoản khác: giải nén RAR mang hạn chế unRAR, nên bản có hỗ trợ RAR không thuần LGPL v3. Danh sách đầy đủ nằm trong [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), còn thông báo bản quyền nằm trong [NOTICE](../../NOTICE).

Cảm ơn tất cả những ai đã dành thời gian cho 7-Zip, cho các thuật toán nén và cho cộng đồng mã nguồn mở nói chung. Không có các bạn, 7-ZSTar sẽ không tồn tại.
