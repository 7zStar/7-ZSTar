<!-- synced-with: docs/INSTALL.md @ 8d159f1 -->
# Cài đặt 7-ZSTar

[English](../INSTALL.md) · [繁體中文](INSTALL.zh-Hant.md) · **Tiếng Việt** · [한국어](INSTALL.ko.md) · [Italiano](INSTALL.it.md) · [Polski](INSTALL.pl.md) · [Türkçe](INSTALL.tr.md) · [Nederlands](INSTALL.nl.md) · [Українська](INSTALL.uk.md) · [Bahasa Indonesia](INSTALL.id.md) · [ไทย](INSTALL.th.md) · [Čeština](INSTALL.cs.md) · [Magyar](INSTALL.hu.md) · [Română](INSTALL.ro.md) · [Svenska](INSTALL.sv.md) · [Ελληνικά](INSTALL.el.md) · [हिन्दी](INSTALL.hi.md) · [العربية](INSTALL.ar.md) · [فارسی](INSTALL.fa.md) · [עברית](INSTALL.he.md)

*Nếu có điểm nào khác với bản tiếng Anh, vui lòng lấy bản tiếng Anh làm chuẩn.*

Trang này đi sâu vào những gì bản rút gọn trong [README](../readme/README.vi.md) chỉ nói qua: yêu cầu hệ thống, cảnh báo của SmartScreen, Kiểm soát Ứng dụng Thông minh và cách kiểm tra một bản tải về, ba gói cài đặt, menu chuột phải của Windows 11, liên kết tệp và việc gỡ cài đặt.

## Yêu cầu hệ thống

**Windows 7 hoặc Windows Server 2008 R2, x64 hoặc x86. Trên arm64, Windows 10.**
Không cần thêm gì khác: thư viện chạy C được liên kết tĩnh (`-MT`), nên các tệp nhị phân chỉ nạp các DLL của chính Windows, không cần gói phân phối lại, không cần .NET.

Mức tối thiểu đó được *suy ra* từ những gì các gói yêu cầu, và đã được thử nghiệm trên Windows 7 SP1 có cài các bản cập nhật về sau (trong đó có PowerShell 5.1), Windows 10 22H2 và Windows 11, tất cả đều 64 bit. Trên Windows 7 và 10, phần thử nghiệm gồm việc cài đặt và gỡ cài đặt `.msi` x64 cho mọi người dùng và cho từng người dùng, trình hướng dẫn cài đặt, tệp `.zip` x64, mọi codec được thêm vào và mọi định dạng tar một bước, menu chuột phải, liên kết tệp và tệp trợ giúp, cùng với `.msi` và `.zip` x86 chạy trên Windows 64 bit. Ngoài ra chưa có gì được thử trên Windows: không có Windows 8 hay 8.1, Windows Server, Windows 32 bit, phần cứng arm64, hay Windows 7 không có các bản cập nhật đó. Mức tối thiểu này cũng cao hơn của 7-Zip gốc, vốn có các tệp nhị phân vẫn nạp được trên Windows XP. Ba điều đẩy nó lên mức này, và điều thứ hai là điều mà không thiết lập biên dịch nào hoàn tác được:

- `.msi` khai báo `InstallerVersion="500"`, và Windows Installer 5.0 được phát hành "with Windows Server 2008 R2 and later and Windows 7 and later" (tức là cùng Windows Server 2008 R2 trở lên và Windows 7 trở lên) ([Microsoft][msi-versions]). Tệp `.zip` di động không đi qua Windows Installer, nhưng xem hai điểm tiếp theo.
- **zstd và fast-lzma2 dùng cơ chế đồng bộ hóa chỉ có từ Vista trở đi.** Cả hai đều ép `_WIN32_WINNT 0x0600` trong các tệp header của riêng mình và gọi trực tiếp `InitializeConditionVariable` / `SleepConditionVariableCS`, vì vậy `7z.dll` và `7za.exe`, hai tệp nhị phân có codec được biên dịch sẵn bên trong, nhập bốn hàm mà Windows XP và Server 2003 không có. `7z.dll` của bản gốc không nhập hàm nào trong số đó.
- Bộ công cụ biên dịch: các tệp này được dựng bằng Visual Studio 2022, có danh sách nền tảng đích được hỗ trợ là Windows 7 trở lên; Vista và Server 2008 là "No" ([Microsoft][vs-targeting]). Phiên bản hệ thống con được liên kết là 6.0 trên x64 và x86 và 6.2 trên arm64, và Windows trên arm64 dù sao cũng bắt đầu từ Windows 10.

Windows Vista và Server 2008 nằm ở giữa: các tệp nhị phân sẽ nạp được, nhưng bộ công cụ biên dịch không hỗ trợ chúng, trình cài đặt sẽ không chạy ở đó, và 7-ZSTar không được thử nghiệm trên chúng.

**Linux chỉ được hỗ trợ dưới dạng bản dựng dòng lệnh; macOS không được hỗ trợ.**
Bản fork dựng một `7zz` gốc (chương trình console `Alone2`) bằng gcc thông qua makefile riêng, makefile này bao gồm các makefile của bản gốc mà không sửa cái nào:
`cd CPP/7zip/Bundles/Alone2 && make -j"$(nproc)" -f makefile.7zstar.gcc`.
Nó chỉ được dựng và thử nghiệm trên Ubuntu 24.04 với gcc 13.3 (x86-64): bản dựng không có cảnh báo nào với các cờ của bản gốc, bài kiểm tra nhanh 77 mục đạt, và 25 vector tương tác tạo trên Windows cùng 37 vector tạo trên Linux cho kết quả giống như trên Windows. Hai tệp do bản fork sở hữu mà việc chuyển nền tảng đã động đến vẫn dựng được không cần sửa trên Windows (bản dựng x64 sạch, bài kiểm tra nhanh và đọc lại tương tác đều đạt). Không có GUI. Các đích Linux khác của bản gốc (`7za`, `7zr`, `7z.so`) không được hỗ trợ: danh sách đối tượng gcc của chúng thiếu những gì các thay đổi của bản fork đối với bộ xử lý của bản gốc cần đến, nên dự kiến chúng sẽ không liên kết được. Các kiến trúc, bản phân phối và trình biên dịch khác chưa được xác minh, và macOS chưa từng được dựng, nên không thể nêu `MACOSX_DEPLOYMENT_TARGET` nào. Các bước dựng, các bài kiểm tra và giới hạn đã biết nằm trong `build/linux/README.md`; khả năng tương tác với các công cụ Linux nằm trong `test/interop/REPORT.md`.

[msi-versions]: https://learn.microsoft.com/en-us/windows/win32/msi/released-versions-of-windows-installer
[vs-targeting]: https://learn.microsoft.com/en-us/visualstudio/releases/2022/compatibility

## Gói chưa ký, SmartScreen và Kiểm soát Ứng dụng Thông minh

**Các trình cài đặt và chương trình trong một bản phát hành 7-ZSTar không được tổ chức phát hành chứng chỉ ký số mã**, và dự án này không có chứng chỉ ký mã nào. Vì vậy Windows không thể biết ai đã phát hành tệp, và khi bạn chạy `.msi`, hay một chương trình trong `.zip`, lần đầu tiên, SmartScreen của Bộ bảo vệ Microsoft có thể chặn lại bằng một cảnh báo. Tài liệu dành cho nhà phát triển của Microsoft liệt kê "No signature" (không có chữ ký) là một trong những trường hợp hiện cảnh báo có tiêu đề "Windows protected your PC" (Windows bảo vệ máy tính của bạn), trong đó người dùng phải chọn "Run anyway" (Chạy dù thế nào đi nữa) thì ứng dụng mới chạy ([Microsoft][smartscreen-rep]). Chính sách của doanh nghiệp có thể loại bỏ hoàn toàn lựa chọn đó; trên một máy như vậy, hãy hỏi người quản lý máy.

Thứ duy nhất trong một bản phát hành *được* ký là gói nhỏ đưa 7-ZSTar lên cấp đầu tiên của menu chuột phải Windows 11, nằm trong `.msi` cho mọi người dùng. Chứng chỉ của nó là chứng chỉ tự ký, được tạo ra khi dựng riêng gói đó, nên không phải chữ ký của một tổ chức phát hành chứng chỉ và không cho biết gì về người dựng gói; xem [menu chuột phải của Windows 11](#menu-chuột-phải-của-windows-11) để biết nó làm gì và cách từ chối nó.

Cảnh báo không chứng minh một tệp là xấu, và việc không có cảnh báo cũng không chứng minh một tệp là tốt. Điều bạn có thể tự kiểm tra là bản của bạn đúng là bản đã đăng trên trang phát hành. Mỗi bản phát hành đều kèm một tệp tên `SHA256SUMS`: mỗi gói một dòng, gồm mã băm SHA-256 theo sau là tên tệp.

1. Tải gói và `SHA256SUMS` từ cùng một trang phát hành, vào cùng một thư mục.
2. Mở PowerShell trong thư mục đó rồi so sánh. Thay tên bằng tên tệp bạn đã tải:

   ```powershell
   $name = '7-ZSTar-26.05.1-x64.msi'
   $expected = ((Get-Content .\SHA256SUMS | Where-Object { $_ -match ([regex]::Escape($name) + '$') }) -split '\s+')[0]
   $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash
   $actual -eq $expected
   ```

   `True` nghĩa là các mã băm giống hệt nhau. Nếu muốn tự xem chúng, hãy chạy
   `Get-FileHash -Algorithm SHA256 .\7-ZSTar-26.05.1-x64.msi` rồi tìm cùng tên
   tệp trong `SHA256SUMS`; phép so sánh không phân biệt chữ hoa và chữ thường.
3. Nếu bạn nhận được `False`, hoặc tên tệp không có trong `SHA256SUMS`, đừng chạy nó: hãy xóa tệp và tải lại. Nếu vẫn không khớp, hãy báo cáo như mô tả trong [SECURITY.md](../../SECURITY.md).

`SHA256SUMS` chỉ bao gồm các tệp được tải lên bản phát hành đó. Tự dựng cùng thẻ (tag) đó sẽ cho mã băm khác (gói menu chuột phải được ký bằng một chứng chỉ mới ở mỗi lần dựng), và mã nguồn được công bố cùng mỗi bản phát hành nếu bạn muốn tự dựng: xem [build/README.md](../../build/README.md).

Khi các mã băm khớp và bạn yên tâm về nguồn gốc của tệp:

- **`.msi`**: khởi chạy như bình thường. Nếu SmartScreen chặn lại, hãy chọn tùy chọn để vẫn chạy ("Run anyway" trên Windows tiếng Anh). Có thể phải mở rộng cửa sổ cảnh báo trước: trên máy Windows 10 được thử nghiệm, nó chỉ có một nút để không chạy tệp cho đến khi nhấp vào liên kết bên dưới thông báo. Sau đó `.msi` cho mọi người dùng sẽ yêu cầu quản trị viên phê duyệt như mọi trình cài đặt khác.
- **`.zip`**: giải nén rồi khởi chạy `7zFM.exe` hoặc `7z.exe` từ thư mục. Các chương trình bên trong cũng không được ký, nên Windows có thể hiện cùng cảnh báo đó vào lần đầu bạn khởi chạy từng chương trình.

SmartScreen cảnh báo dựa trên mức độ phổ biến của một tệp, không chỉ dựa trên chữ ký; một tệp ít người tải về có thể gây ra cảnh báo ngay cả khi đã được ký. Không có gì ở đây thay đổi điều đó, và không bước nào ở trên tắt SmartScreen.

### Kiểm soát Ứng dụng Thông minh trên Windows 11

Một số máy Windows 11 bật sẵn một lớp bảo vệ chặt chẽ hơn gọi là **Kiểm soát Ứng dụng Thông minh**. Khi nó đang bật, Windows chặn các tệp chưa ký trừ khi dịch vụ đám mây của Microsoft có thể bảo đảm cho chúng, và một bản phát hành mới thường chưa có bản ghi nào như vậy ([Microsoft][sac-faq], [Microsoft][smartscreen-rep]). Không giống cảnh báo của SmartScreen, việc chặn này không có tùy chọn để vẫn chạy tệp, và phần hỏi đáp của Microsoft nói rằng không có cách nào vượt qua Kiểm soát Ứng dụng Thông minh cho một ứng dụng riêng lẻ.

Những gì đã xảy ra khi thử 7-ZSTar 26.05.1 trên Windows 11 Pro 25H2 (bản dựng 26200.8037) với Kiểm soát Ứng dụng Thông minh ở trạng thái Bật:

- **Các trình cài đặt `.msi` bị chặn**, cả bản cho mọi người dùng lẫn bản cho từng người dùng. Trên một Windows tiếng Trung phồn thể, Windows Installer hiện 「系統禁用此安裝。請連絡系統管理員。」, và một thông báo của Bảo mật Windows cho biết Kiểm soát Ứng dụng Thông minh đã chặn tệp vì Windows không thể biết ai đã phát hành nó và nó không phải là ứng dụng Windows biết. Không có tùy chọn nào để tiếp tục, và `msiexec /i ... /qn` trả về lỗi 1625. Thông báo đó là chuỗi 1625 của Windows Installer; trên Windows tiếng Anh, cùng chuỗi đó có nội dung "The system administrator has set policies to prevent this installation." (đọc từ tài nguyên tiếng Anh của Windows Installer, không thấy trên màn hình).
- **Một chương trình trong `.zip` đã chạy được.** `7zFM.exe`, giải nén từ `.zip` di động, khởi động bình thường trong cùng bài thử. Việc Windows có cho một chương trình chưa ký chạy hay không là do Windows tự đánh giá tệp đó, nên trên máy của bạn có thể khác.
- Ngay sau khi Kiểm soát Ứng dụng Thông minh được bật, `.msi` vẫn cài được trong vài phút trước khi bắt đầu bị chặn. Chưa tìm ra nguyên nhân, nên việc cài thành công ngay sau khi bật không có nghĩa là trình cài đặt được cho phép.

Vì vậy trên một máy có Kiểm soát Ứng dụng Thông minh đang bật, **không thể cài các trình cài đặt**, và việc kiểm tra `SHA256SUMS` không thay đổi điều đó. Điều có tác dụng là tắt Kiểm soát Ứng dụng Thông minh trong Cài đặt Kiểm soát Ứng dụng Thông minh của ứng dụng Bảo mật Windows (trên Windows tiếng Trung phồn thể được thử nghiệm: Windows 安全性, 應用程式與瀏覽器控制, 智慧型應用程式控制設定). Trong bài thử, việc chọn tùy chọn Tắt có hiệu lực ngay lập tức, không cần khởi động lại, và sau đó các trình cài đặt cài được. Đây là một thiết lập cho cả máy và không có gì ở đây yêu cầu bạn thay đổi nó: quyết định là của bạn, hoặc của quản trị viên nếu là máy được quản lý.

Việc có bật lại được hay không cũng đáng biết trước. Phần hỏi đáp của Microsoft nói rằng các bản cập nhật Windows gần đây cho phép bật lại Kiểm soát Ứng dụng Thông minh mà không cần cài đặt sạch Windows, nên trên phiên bản không có các bản cập nhật đó, việc tắt nó có thể là vĩnh viễn. Trên bản dựng được thử ở đây, tùy chọn để bật vẫn được đưa ra sau khi tắt; đó là kết quả thử nghiệm, không phải lời cam kết về phiên bản của bạn.

[smartscreen-rep]: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
[sac-faq]: https://support.microsoft.com/en-us/windows/smart-app-control-frequently-asked-questions-285ea03d-fa88-4d56-882e-6698afdb7003

## Cài đặt

Ba gói, tất cả đều được tạo bởi `installer\Build-Package.ps1` (gói cho từng người dùng dùng thêm `-PerUser`):

| | `.msi` | `-user.msi` | `.zip` |
|---|---|---|---|
| Cài đặt cho | mọi tài khoản | tài khoản đang cài đặt | - |
| Menu chuột phải của File Explorer | có | có, chỉ menu cổ điển ([bên dưới](#gói-cài-cho-từng-người-dùng)) | không |
| Mục trong *Menu Bắt đầu* | có | có | không |
| Cần quản trị viên | có | không | không |
| Gỡ cài đặt | *Ứng dụng đã cài đặt* trong Cài đặt | *Ứng dụng đã cài đặt* trong Cài đặt | xóa thư mục |

*Ứng dụng đã cài đặt* là tên gọi trong Windows 11. Windows 10 gọi cùng trang đó là *Ứng dụng và Tính năng*, còn trên Windows 7 đó là *Programs and Features* (chương trình và tính năng) trong Control Panel (bảng điều khiển).

Hãy dùng gói khớp với chính Windows: x86 trên Windows 32 bit, x64 trên Windows 64 bit, arm64 trên Windows on Arm (các gói arm64 có được dựng nhưng chưa từng được chạy). Phần mở rộng shell x86 là 32 bit và File Explorer 64 bit không thể nạp nó, nên trên Windows 64 bit, `-user.msi` x86 hoàn toàn không có menu chuột phải, còn `.msi` x86 chỉ có trên Windows 11 và chỉ cho những tài khoản đã đăng ký gói Windows 11 của nó (tài khoản đã cài đặt, hoặc một tài khoản đã chạy `-Register`, xem bên dưới).

MSI cài vào `Program Files\7-ZSTar`, luôn luôn như vậy: không giống gói cho từng người dùng, nó không cho chọn thư mục và bỏ qua `INSTALLFOLDER` trên dòng lệnh, vì thư mục đó chứa một tập lệnh mà trình cài đặt chạy với quyền SYSTEM và một DLL mà File Explorer của mọi người dùng nạp, còn một thư mục tạo ở nơi khác (chẳng hạn dưới `C:\`) thì mọi người dùng đều ghi vào được. Nó đăng ký CLSID phần mở rộng shell riêng và hive registry `Software\7-ZSTar` riêng, và đặt tên mọi khóa menu ngữ cảnh là `7-ZSTar`, nên không xung đột với, cũng không gỡ mất, những khóa của 7-Zip chính thức. Xem [installer/GUIDS.md](../../installer/GUIDS.md).

Nó chạy một trình hướng dẫn cài đặt thông thường (welcome, licence, setup type, optional feature tree, finish: chào mừng, giấy phép, kiểu cài đặt, cây tính năng tùy chọn, hoàn tất) và cài đặt im lặng vẫn hoạt động như cũ (`msiexec /i 7-ZSTar-<version>-<arch>.msi /qn`), vì msiexec bỏ qua toàn bộ chuỗi giao diện ở chế độ im lặng. Trình hướng dẫn chỉ có tiếng Anh, kể cả trên Windows được đặt sang ngôn ngữ khác (đã thấy trên Windows 10 tiếng Trung phồn thể; `.msi` được dựng không có ngôn ngữ nào khác), và trang cuối của nó có ô *Launch 7-ZSTar File Manager* được đánh dấu sẵn theo mặc định.

### Menu chuột phải của Windows 11

Trên Windows 11, mục này nằm ở menu cấp đầu tiên, không bị chôn dưới *Xem thêm tùy chọn* như 7-Zip chính thức và WinRAR vẫn đang ở đó. Windows 11 chỉ liệt kê một phần mở rộng shell ở đó khi nó đi kèm danh tính gói, nên MSI kèm theo một gói MSIX nhỏ chỉ chứa danh tính bên cạnh chương trình và đăng ký nó trong lúc cài đặt. Cách đăng ký cổ điển cũng được giữ lại. Chính nó đưa mục này vào menu chuột phải trên Windows 10 và Windows 7, vốn có menu chỉ một cấp và không có *Xem thêm tùy chọn*, và cũng chính nó giữ cho mục này hoạt động với những ai đã khôi phục menu ngữ cảnh cũ.

Gói đó được ký bằng một **chứng chỉ tự ký**, và trình cài đặt đặt nó vào `LocalMachine\TrustedPeople`: Windows sẽ không triển khai một gói mà chữ ký của nó không liên kết được tới thứ gì đáng tin. Gỡ cài đặt sẽ xóa chứng chỉ cùng với gói. Trên Windows 10 và Windows 7, trình cài đặt không làm cả hai việc: nó không thêm chứng chỉ nào và không đăng ký gói nào, và chỉ riêng cách đăng ký cổ điển cung cấp menu.

Nếu bạn không muốn tin cậy một chứng chỉ tự ký, hãy từ chối riêng phần đó và giữ lại mọi thứ còn lại:

```
msiexec /i 7-ZSTar-<version>-<arch>.msi SPARSE=0
```

Khi đó bạn chỉ có menu cổ điển, nên trên Windows 11 mục 7-ZSTar nằm trong menu chuột phải dưới *Xem thêm tùy chọn*. Để bật mục cấp đầu tiên sau này, hoặc để hoàn tác nó sau một lần cài đặt bình thường:

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -TrustCert -Register
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -Unregister -UntrustCert
```

Tin cậy chứng chỉ đó nghĩa là Windows cũng sẽ chấp nhận **bất kỳ gói nào khác** được ký bằng cùng khóa mà không cảnh báo. Nó chỉ được dùng cho đúng gói này, và gỡ cài đặt sẽ gỡ nó ra lại, nhưng đó là điều bạn đang đồng ý: `SPARSE=0` ở trên là cách để từ chối.

Việc đăng ký gói là theo từng người dùng, và trình cài đặt chỉ thực hiện nó cho người đã cài đặt. Hai hệ quả:

- Tài khoản thứ hai trên cùng máy chỉ có menu cổ điển, cho đến khi nó chạy cùng tập lệnh đó với `-Register`.
- Gỡ cài đặt chỉ hủy đăng ký cho người đang gỡ. Nếu người khác đã đăng ký, đăng ký của họ vẫn tồn tại sau khi gỡ cài đặt và trỏ tới một thư mục không còn nữa; tài khoản đó xóa nó bằng `Get-AppxPackage 7-ZSTar | Remove-AppxPackage`.

**Hạn chế đã biết: menu cấp đầu tiên chỉ được đăng ký khi việc cài đặt chạy trong một phiên tương tác đã đăng nhập.** Cài `.msi` cho mọi người dùng từ một phiên từ xa hoặc không tương tác, qua SSH hoặc triển khai im lặng từ một công cụ quản lý, vẫn báo thành công nhưng gói Windows 11 không được đăng ký, nên chỉ xuất hiện menu cổ điển dưới *Xem thêm tùy chọn*. Trong bài thử, `msiexec /i ... /qn` từ một phiên SSH (phiên 0) thoát với mã 0 trong khi `Setup-ShellIntegration.ps1` báo `registration failed: 0x80070005` (từ chối truy cập); cùng `.msi` đó cài từ phiên console của một quản trị viên thì đăng ký bình thường.

`-Status` in ra những gì đã có và chưa có.

### Gói cài cho từng người dùng

`7-ZSTar-<version>-<arch>-user.msi` chỉ cài cho tài khoản hiện tại, vào `%LOCALAPPDATA%\Programs\7-ZSTar`, không có lời nhắc Kiểm soát Tài khoản Người dùng. Mọi thứ nó đăng ký đều nằm dưới `HKCU`; gói không ghi gì vào `HKLM` (ngoài phần sổ sách riêng của Windows Installer). Những gì nó không làm được như gói cho cả máy:

- **Không có menu cấp đầu tiên của Windows 11.** Trên Windows 11, 7-ZSTar nằm trong menu chuột phải dưới *Xem thêm tùy chọn*. Mục cấp đầu tiên cần chứng chỉ tự ký được tin cậy trên toàn máy, việc này đòi hỏi quản trị viên: đo trên Windows 11, một chứng chỉ trong `CurrentUser\TrustedPeople` không đủ để Windows triển khai gói. Vì vậy gói cho từng người dùng bỏ nó đi.
- **Chỉ một trong hai gói trên mỗi máy.** Mỗi gói từ chối cài đặt khi gói kia đang được cài; hãy gỡ một gói trước khi cài gói còn lại. Gói cho cả máy chỉ thấy được bản cho từng người dùng của tài khoản đang chạy nó, nên bản cài cho từng người dùng của tài khoản khác không được phát hiện.
- **Group policy (chính sách nhóm) có thể ẩn menu của nó.** Ở nơi `EnforceShellExtensionSecurity` được đặt, File Explorer chỉ nạp các phần mở rộng shell được liệt kê dưới khóa *Approved* trên toàn máy, nơi mà bản cài cho từng người dùng không ghi được, nên menu chuột phải không xuất hiện. Ở đó hãy dùng gói cho cả máy.
- **Xóa một định dạng trong Công cụ > Tùy chọn > Hệ thống cũng gỡ lời mời của 7-ZSTar cho định dạng đó.** Khi bạn xóa một định dạng ở đó (nhấp vào ô của nó cho đến khi trống, rồi Đồng ý), trình quản lý tệp xóa toàn bộ các khóa `HKCU\Software\Classes\.<ext>` và `7-ZSTar.<ext>`, và với bản cài cho từng người dùng, các khóa đó cũng chứa những gì gói đã đăng ký cho Cài đặt > Ứng dụng > Ứng dụng mặc định và danh sách *Mở bằng*. Khi đó 7-ZSTar biến mất khỏi *Mở bằng* cho định dạng ấy, và Ứng dụng mặc định hiện một mục trống cho nó. Sửa chữa bản cài đặt sẽ đưa nó trở lại (chạy lại `.msi` và chọn *Repair*, tức sửa chữa). Tốt hơn, hãy gán các loại tệp trong Ứng dụng mặc định thay vì trong trình quản lý tệp. Gói cho cả máy cũng có cùng điểm yếu ở một chỗ, được mô tả bên dưới ở phần liên kết tệp.

### Liên kết tệp và tác động của việc gỡ cài đặt

**Hãy thiết lập chúng trong Cài đặt > Ứng dụng > Ứng dụng mặc định.** Trên Windows 11, gõ 7-ZSTar ở đó và mọi định dạng nó mở được sẽ được liệt kê để gán. Trên Windows 10, 7-ZSTar được liệt kê dưới *Set defaults by app* (đặt mặc định theo ứng dụng) trên trang đó, nơi *Manage* (quản lý) hiện các định dạng của nó. Windows 7 không có ứng dụng Cài đặt: 7-ZSTar được liệt kê trong Control Panel (bảng điều khiển) > Chương trình Mặc định > *Đặt chương trình mặc định của bạn*, đó là điều mà *Ứng dụng mặc định* trong hướng dẫn này chỉ đến ở đó. Việc gán các định dạng từ hai trang đó chưa được thử nghiệm. Trình cài đặt đăng ký 7-ZSTar như một ứng dụng Chương trình Mặc định, gồm một ProgID cho mỗi định dạng kèm biểu tượng và lệnh mở, một mục trong danh sách *Mở bằng* của mỗi phần mở rộng, và khối Capabilities mà Windows đọc, nhưng cố ý không giành loại tệp nào: chương trình nào mở kho lưu trữ của bạn là quyết định của bạn, và đó là điều giúp 7-ZSTar và 7-Zip chính thức không cản đường nhau. Windows vẫn có thể tự chuyển một định dạng sang 7-ZSTar khi không chương trình nào khác đề nghị mở nó: trên các máy Windows 10 và Windows 7 được thử nghiệm, nơi không có gì khác từng đăng ký `.7z`, một tệp `.7z` hiện biểu tượng của 7-ZSTar và mở bằng nó khi nhấp đúp, mà Windows không hỏi dùng chương trình nào.

**Công cụ > Tùy chọn > Hệ thống trong trình quản lý tệp phần lớn không hoạt động trên Windows 11**, và đó là quy tắc của Windows chứ không phải lỗi ở đây. Nó ghi một ProgID `7-ZSTar.<ext>` vào `HKCU\Software\Classes`, và với bất kỳ phần mở rộng nào mà máy đã biết, mà mọi định dạng kho lưu trữ đều như vậy, Windows 11 bỏ qua nó: `AssocQueryString` trả lời `Unknown` và File Explorer vẽ biểu tượng chung trống. Thứ nó tôn trọng thay vào đó là khóa `UserChoice` được đóng dấu bằng một mã băm mà chỉ Windows mới tính được, đó là lý do giao diện Cài đặt là con đường duy nhất ở đó. Không ứng dụng nào ghi được một khóa như vậy: không phải 7-ZSTar, không phải 7-Zip, không phải bất kỳ trình cài đặt nào. Windows 10 và Windows 7 cư xử khác trong lúc thử nghiệm: sau khi `.7z` và `.zst` được đặt trong trình quản lý tệp, mà không chọn chương trình nào khác cho chúng, `AssocQueryString` trả về `7zFM.exe` cho cả hai.

**Xóa một định dạng trong cột *All users* sẽ gỡ đăng ký riêng của gói cho cả máy cho định dạng đó.** Cột đó ghi vào `HKLM\Software\Classes`, nơi gói cho cả máy giữ các ProgID và các mục *Mở bằng* mà nó đề xuất, và việc xóa một định dạng ở đó (cần chạy trình quản lý tệp bằng *Chạy với tư cách quản trị viên*) xóa toàn bộ các khóa đó, cho mọi tài khoản. Sửa chữa đã khôi phục cùng các khóa đó cho gói cho từng người dùng; với gói này thì chưa được đo.

**Một biểu tượng vẫn trống sau khi thay đổi bất cứ điều gì** cũng có thể là do bộ nhớ đệm biểu tượng của File Explorer, vốn không nhận ra rằng một DLL đã được lưu đệm đã bị thay thế; `ie4uinit.exe -show` không xóa nó một cách đáng tin cậy. Hãy đóng File Explorer, xóa `%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache_*.db`, rồi khởi động lại.

**Gỡ cài đặt sẽ xóa những liên kết mà nó với tới được**: các ProgID `7-ZSTar.*` thuộc về người đang gỡ, và chỉ những loại tệp vẫn còn trỏ tới chúng, nên một định dạng đã được giao cho chương trình khác trong thời gian đó sẽ được để yên. Gỡ cài đặt gói cho cả máy cũng để yên một ProgID mở một bản sao của 7-ZSTar ở nơi khác vẫn còn tồn tại, chẳng hạn một bản di động từ `.zip`, được thiết lập bằng **Công cụ > Tùy chọn > Hệ thống** của chính bản sao đó. Gói cho từng người dùng thì không làm được: các ProgID của nó chính là những khóa `HKCU` đó (xem *Gói cài cho từng người dùng* ở trên), và gỡ cài đặt sẽ xóa chúng bất kể ai ghi sau cùng. Để chúng lại sẽ khiến các loại tệp đó trỏ tới một ProgID có biểu tượng và lệnh là một tệp thực thi đã bị xóa, tức là một biểu tượng trống và một lỗi khi nhấp đúp. Liên kết của các tài khoản khác nằm ngoài tầm với; họ có thể xóa liên kết của chính mình bằng `Setup-ShellIntegration.ps1 -RemoveAssociations` trước khi chương trình bị gỡ. `msiexec /x ... KEEPASSOC=1` bỏ qua bước này, và nâng cấp thì không bao giờ thực hiện nó.

**Hạn chế đã biết: các tài khoản khác giữ những liên kết do chính họ đặt.** Gỡ cài đặt gói cho cả máy chỉ xóa những gì tài khoản đang chạy việc gỡ đã đặt trong cột của chính nó (có tiêu đề là tên tài khoản) dưới **Công cụ > Tùy chọn > Hệ thống** trong trình quản lý tệp. Bất kỳ tài khoản nào khác đã đặt liên kết ở đó vẫn giữ chúng, trỏ tới chương trình đã bị gỡ, nên khi nhấp đúp vào một tệp `.7z`, Windows sẽ hỏi dùng chương trình nào. Mỗi tài khoản nên xóa liên kết của mình **trước** khi gỡ cài đặt, bằng

```
powershell -ExecutionPolicy Bypass -File "C:\Program Files\7-ZSTar\Setup-ShellIntegration.ps1" -RemoveAssociations
```

lệnh này chỉ xóa các mục của 7-ZSTar, hoặc sau đó gán lại các loại tệp trong Cài đặt > Ứng dụng > Ứng dụng mặc định. Làm việc đó trong trình quản lý tệp thì nghĩa là nhấp vào từng ô trong cột của chính mình đang hiện 7-ZSTar cho đến khi trống, rồi Đồng ý; đừng chọn tất cả các hàng rồi nhấn "+", vì nó áp một trạng thái cho mọi hàng được chọn và do đó cũng xóa những định dạng thuộc về chương trình khác, chẳng hạn 7-Zip chính thức.

Các liên kết đặt trong cột **All users** hoàn toàn không bị phần dọn dẹp khi gỡ cài đặt đụng tới, và để mọi tài khoản trỏ tới chương trình đã bị gỡ. Quản trị viên nào đã đặt liên kết nào ở đó nên xóa các ô đó, từ một trình quản lý tệp chạy bằng *Chạy với tư cách quản trị viên*, rồi Đồng ý, trước khi gỡ cài đặt; `-RemoveAssociations` không tới được cột này. Xóa nó ngay trước khi gỡ cài đặt là vô hại, dù nó xóa đăng ký riêng của gói ở đó (xem trên), vì dù sao việc gỡ cài đặt cũng sẽ gỡ nó. Gói cho từng người dùng không có vấn đề với các tài khoản khác, và 7-Zip chính thức cũng cư xử như vậy.

## Ngôn ngữ

Mỗi gói đều mang theo các bản dịch của bản gốc, hơn 90 ngôn ngữ. Hãy chọn một ngôn ngữ trong **Công cụ > Tùy chọn > Ngôn ngữ hiển thị**; MSI cũng cho phép bỏ chúng đi trong cài đặt *Custom*. 7-ZSTar cố gắng theo ngôn ngữ hệ thống ở lần chạy đầu tiên, nhưng việc dò tìm đó bỏ cuộc và giữ tiếng Anh khi thiết lập "language for non-Unicode programs" (ngôn ngữ cho chương trình không dùng Unicode) của Windows và thiết lập Định dạng khu vực không khớp nhau: tự chọn ngôn ngữ bằng tay thì luôn được.

Các chuỗi do chính 7-ZSTar thêm vào, tức các trường mức nén và từ điển của zstd, các tên định dạng kho lưu trữ mới, không có bản dịch của bản gốc và vẫn là tiếng Anh. Ngoại lệ là các nút **Ủng hộ** và **Trang web** của hộp thoại Về 7-ZSTar: 67 trong số 92 ngôn ngữ có từ riêng cho mỗi nút, 25 ngôn ngữ còn lại hiện tiếng Anh (`Lang/UPSTREAM.md` liệt kê chúng).
Các bản dịch được đưa nguyên vào, không viết ở đây: xem [Lang/UPSTREAM.md](../../Lang/UPSTREAM.md).
