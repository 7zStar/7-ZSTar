<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../logo/wordmark-dark@3x.png">
  <img src="../logo/wordmark-light@3x.png" alt="7-ZSTar" width="230">
</picture>

[English](../../README.md) · [繁體中文](README.zh-Hant.md) · [简体中文](README.zh-Hans.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (Brasil)](README.pt-BR.md) · [日本語](README.ja.md) · **Tiếng Việt** · [한국어](README.ko.md) · [العربية](README.ar.md) · [Esperanto](README.eo.md)

**Bản fork của 7-Zip thân thiện hơn với người dùng Windows 11 hiện đại: menu chuột phải ở cấp đầu tiên, nén zstd và tar.zst trong một lượt.**

[Tải xuống](https://github.com/7zStar/7-ZSTar/releases/latest) · [Trang web](https://www.7zstar.com/vi/) · [Nhật ký thay đổi](../../CHANGELOG.md)

## Vì sao chọn 7-ZSTar

- **Không cần bấm “Xem thêm tùy chọn” nữa.** Cài MSI cho mọi người dùng, 7-ZSTar sẽ nằm ở cấp đầu tiên của menu chuột phải trên Windows 11.
- **Một lượt. Không có .tar trên đĩa.** Nén sang tar.zst và giải nén tar.zst mỗi việc chỉ một bước, và cả hai chiều đều không ghi tệp .tar. 7-Zip chính thức không tạo được .tar.zst, còn giải nén thì phải qua hai bước, đi qua một tệp .tar.
- **Nhanh gấp 10 lần 7z.** Trên các thư mục dự án thực tế, tar.zst nén nhanh hơn 7z từ 10 đến 18 lần.

## Tốc độ

| Thư mục | Số tệp | Dung lượng gốc | zip | 7z | tar.zst |
|---|---|---|---|---|---|
| Node `node_modules` | 13.371 | 207 MB | 4,1 giây / 76,7 MB | 38,4 giây / 51,8 MB | **3,8 giây** / 59,7 MB |
| Python `.venv` | 9.795 | 346 MB | 6,6 giây / 107,8 MB | 54,8 giây / 65,7 MB | **3,6 giây** / 83,4 MB |
| Python `.venv` (tệp nhị phân lớn) | 11.654 | 671 MB | 25,5 giây / 249,5 MB | 100,8 giây / 167,2 MB | **5,6 giây** / 210,9 MB |

tar.zst nhỏ hơn zip từ 15 đến 23% mà không chậm hơn. Tuy vậy, nó lớn hơn 7z từ 15 đến 27%, nên nếu dung lượng nhỏ nhất là ưu tiên hàng đầu thì 7z vẫn là lựa chọn phù hợp. Các số liệu này là của việc nén; khi giải nén, cả ba mất thời gian xấp xỉ nhau.

zip, 7z và tar.zst đều dùng cài đặt mặc định. 7-ZSTar 26.05.1 x64 (7z.exe), một máy (Intel Core Ultra 7 155H, NVMe SSD), ba thư mục dự án thực tế, trung vị của 3 lượt chạy, 2026-11.

## Định dạng

- **Nén trong một bước (8):** tar.zst, tar.br, tar.lz4, tar.lz5, tar.liz, tar.gz, tar.bz2, tar.xz
- **Giải nén trong một bước (10):** 8 định dạng trên, cộng thêm tar.lzma và tar.Z
- **Codec bổ sung:** zstd, brotli, lz4, lz5 và lizard, mỗi loại vừa là một định dạng độc lập vừa là một phương pháp bên trong .7z; thêm fast-lzma2 làm bộ mã hóa LZMA2 thay thế.
- Mọi định dạng mà 7-Zip đã hỗ trợ vẫn còn nguyên.

Khi giải nén tar.br, tar.lz4, tar.lz5, tar.liz hoặc tar.Z, với bạn vẫn chỉ là một bước, nhưng 7-ZSTar giải mã ra một tệp trung gian trước rồi xóa nó đi sau đó.

## Dòng lệnh

```
7z a -ttar.zst backup.tar.zst docs
7z x backup.tar.zst -oout
```

Trong PowerShell, hãy đặt tham số định dạng trong dấu ngoặc kép, như `7z a "-ttar.zst" backup.tar.zst docs`. Nếu không có dấu ngoặc kép, PowerShell sẽ tách `-ttar.zst` làm hai và 7z tạo ra một tệp tên là `.zst`. Command Prompt (cmd) không cần dấu ngoặc kép.

## Tải xuống và cài đặt

| | MSI cho mọi người dùng `.msi` | Riêng bạn `-user.msi` | ZIP không cần cài đặt `.zip` |
|---|---|---|---|
| Cài cho | Mọi tài khoản trên máy | Tài khoản hiện tại | Không cần cài đặt |
| Cần quyền quản trị viên | Có | Không | Không |
| Menu chuột phải | Cấp đầu tiên của Windows 11 | Trong “Xem thêm tùy chọn” | Không có |
| Mục trong menu Bắt đầu | Có | Có | Không |

Mỗi loại đều có bản x64, x86 và arm64; hãy chọn bản khớp với Windows của bạn: trên Windows 64-bit, các gói x86 có thể không có menu chuột phải. Các bản arm64 chưa từng chạy trên phần cứng thật. 7-ZSTar cài song song với 7-Zip chính thức, hai bên không ảnh hưởng lẫn nhau.

**Windows có thể cảnh báo về các bản tải xuống này.** Các trình cài đặt và chương trình không được ký mã (code-sign) bởi một tổ chức cấp chứng chỉ, nên Microsoft Defender SmartScreen có thể chặn chúng bằng một cảnh báo ở lần chạy đầu tiên, và trên máy Windows 11 bật Smart App Control thì các trình cài đặt `.msi` bị chặn hẳn, không có tùy chọn tiếp tục. Điều đó không có nghĩa là tệp có vấn đề: mỗi bản phát hành đều kèm một tệp `SHA256SUMS`, và bạn có thể kiểm tra xem tệp tải về có khớp với bản đã được công bố hay không. Cách kiểm tra, ý nghĩa của Smart App Control đối với bạn, và cách tiếp tục khi tệp đã khớp nằm trong [docs/INSTALL.md](../INSTALL.md#unsigned-packages-smartscreen-and-smart-app-control).

**Về menu cấp đầu tiên:** Windows 11 chỉ cho các chương trình có danh tính gói (package identity) lên cấp đầu tiên, nên MSI cho mọi người dùng cài một gói MSIX nhỏ được ký bằng chứng chỉ tự ký và tin cậy chứng chỉ đó. Gỡ cài đặt sẽ xóa cả hai. Nếu bạn không muốn tin cậy chứng chỉ này, hãy cài bằng `msiexec /i 7-ZSTar-<phiên bản>-<kiến trúc>.msi SPARSE=0`, khi đó menu vẫn nằm trong “Xem thêm tùy chọn”. Gói chỉ được đăng ký cho tài khoản chạy trình cài đặt; các tài khoản khác phải đăng ký riêng.

Toàn bộ chi tiết, gồm cả liên kết tệp và cách gỡ cài đặt, nằm trong [docs/INSTALL.md](../INSTALL.md) (hiện chỉ có tiếng Anh).

## Hạn chế đã biết

- **Bỏ chọn hộp kiểm tích hợp vào shell sẽ xóa đăng ký menu chuột phải.** Trong trình quản lý tệp (`7zFM`), mục **Công cụ > Tùy chọn > 7-ZSTar** có một hộp kiểm tên “Tích hợp 7-ZSTar vào menu ngữ cảnh”. Giống 7-Zip chính thức, bỏ chọn hộp kiểm này sẽ xóa đăng ký của phần mở rộng shell (khóa `CLSID`) mà trình cài đặt đã tạo, và mục 7-ZSTar biến mất khỏi menu chuột phải. Với gói cho mọi người dùng, bạn có thể chọn lại hộp kiểm khi trình quản lý tệp chạy với quyền quản trị viên. Với gói riêng bạn thì không được: chọn lại sẽ hiện “Quyền truy nhập bị từ chối” và mục đó vẫn mất. Để lấy lại, hãy chạy lại tệp `.msi` ban đầu rồi chọn *Repair* (sửa chữa).
- **Menu cấp đầu tiên chỉ được đăng ký khi việc cài đặt chạy trong một phiên tương tác, đã đăng nhập.** Cài `.msi` cho mọi người dùng từ một phiên từ xa hoặc không tương tác (qua SSH, hoặc triển khai im lặng từ một công cụ quản lý) vẫn báo thành công, nhưng gói dành cho Windows 11 không được đăng ký, nên chỉ có menu cổ điển trong “Xem thêm tùy chọn” xuất hiện. Chi tiết nằm trong [docs/INSTALL.md](../INSTALL.md#the-windows-11-right-click-menu).

## Yêu cầu hệ thống

Windows 7 hoặc Windows Server 2008 R2 trở lên (x64, x86); Windows 10 trở lên trên arm64. Không cần cài thêm gì khác. Mức tối thiểu này suy ra từ yêu cầu của các gói; các phiên bản cũ hơn Windows 11 chưa được kiểm thử. Trên Linux có bản dòng lệnh để bạn tự biên dịch; macOS không được hỗ trợ.

## Về dự án này

7-ZSTar là bản fork của 7-Zip thân thiện hơn với người dùng Windows 11 hiện đại. Lõi của 7-Zip rất xuất sắc, nhưng một số chỗ chưa theo kịp cách mọi người làm việc ngày nay: Windows 11 giấu nó sau “Xem thêm tùy chọn”, và nó cũng không nén được sang zstd. 7-ZSTar lấp những khoảng trống đó và giữ nguyên mọi thứ còn lại như bạn đã quen.

## Tài liệu

Mỗi gói đều kèm `7-zip.chm`, tệp trợ giúp của 7-Zip chính thức, giữ nguyên không sửa: **Giúp đỡ > Nội dung** và phím F1 sẽ mở nó. Trong đó chỗ nào cũng ghi “7-Zip” và không nói về những gì 7-ZSTar bổ sung; về phần đó, hãy xem trang này và [CHANGELOG.md](../../CHANGELOG.md).

Nếu tệp trợ giúp không nằm cạnh tệp thực thi, chính các mục đó sẽ mở phần này trên mạng (bằng tiếng Anh).

## Xây dựng từ mã nguồn

Xem [build/README.md](../../build/README.md). Tóm tắt: VS2022 Build Tools (MSVC v143), rồi chạy `pwsh build\Build.ps1`. Trước khi hợp nhất một bản upstream mới, hãy đọc [MAINTAINING.md](../../MAINTAINING.md).

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

LGPL v3, xem [LICENSE](../../LICENSE). Một số phần đi kèm điều khoản khác: ví dụ giải nén RAR mang hạn chế unRAR, nên bản có hỗ trợ RAR không thuần LGPL v3. Danh sách đầy đủ nằm trong [LICENSE-EXCEPTIONS.md](../../LICENSE-EXCEPTIONS.md), thông báo bản quyền của mọi thành phần nằm trong [NOTICE](../../NOTICE).

## Lời cảm ơn

7-ZSTar đứng trên vai của rất nhiều người. Cảm ơn tất cả những ai đã dành thời gian cho 7-Zip, cho các thuật toán nén và cho cộng đồng mã nguồn mở nói chung. Không có các bạn, phần mềm này sẽ không tồn tại.
