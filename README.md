# 🚀 MacAppCleaner

> **Ứng dụng dọn dẹp & gỡ bỏ phần mềm chuyên sâu, phân tích dung lượng ổ đĩa trực quan dành cho macOS.**  
> Được xây dựng 100% bằng **Swift 6 & SwiftUI**, giao diện native tuyệt đẹp, siêu nhẹ (~1.1 MB), tốc độ quét APFS cực nhanh và tích hợp **Hàng rào an toàn (SafetyGuard)** ngăn chặn 100% việc xoá nhầm file hệ điều hành.

---

## 🌟 Tính Năng Nổi Bật

### 1. 🗑️ Gỡ Bỏ Hoàn Toàn Ứng Dụng (Deep Residual Uninstaller)
* **Thuật toán quét tàn dư chuyên sâu** (Kế thừa và tối ưu từ chuẩn mã nguồn mở của **Pearcleaner** & **AppCleaner**).
* Tự động phát hiện và liên kết mọi tệp rác mà các ứng dụng để lại:
  * `~/Library/Application Support/{BundleID | AppName}`
  * `~/Library/Caches/{BundleID | AppName}`
  * `~/Library/Preferences/{BundleID}.plist`
  * `~/Library/Saved Application State/{BundleID}.savedState`
  * `~/Library/Containers/{BundleID}` (Dữ liệu hộp cát Sandbox)
  * `~/Library/Group Containers/{AppGroup}`
  * `~/Library/Logs/{BundleID | AppName}`
  * `~/Library/WebKit/{BundleID}`
  * `~/Library/HTTPStorages/{BundleID}`
  * `~/Library/LaunchAgents` & `/Library/LaunchAgents` (Tiến trình chạy nền khởi động cùng máy)
* **Đọc Header nhị phân Mach-O**: Nhận diện kiến trúc CPU chính xác (**Apple Silicon `arm64`**, **Intel `x86_64`**, hoặc **Universal 2**).
* **Tuỳ chọn linh hoạt**: Bảng danh sách tệp con kèm hộp kiểm (checkbox) cho phép người dùng chọn lọc từng tệp muốn giữ lại hoặc xoá.

### 2. 📊 Phân Tích Dung Lượng Ổ Đĩa (Disk Storage Analyzer)
* **Kiến trúc phân cấp thư mục dạng cột** (Lấy cảm hứng từ sự tiện lợi của **OmniDiskSweeper**).
* Quét đệ quy đa luồng cực nhanh qua Swift Concurrency `TaskGroup` và đo đạc kích thước thực tế phân bổ trên hệ thống tệp APFS (`totalFileAllocatedSizeKey`).
* Tự động sắp xếp thư mục từ lớn nhất đến nhỏ nhất kèm thanh tỷ lệ phần trăm dung lượng trực quan.
* Hỗ trợ đào sâu (Double-click để duyệt vào thư mục con, nút "Thư mục trước" để quay lại).
* **Bộ lọc thông minh tức thì**:
  * **Tệp lớn (>500MB)**: Gom nhóm các tệp video, file nén, disk images (.dmg, .iso)...
  * **Tệp khổng lồ (>2GB)**: Phát hiện ngay lập tức các tệp chiếm dụng bộ nhớ nghiêm trọng nhất.

### 3. 🛡️ Hàng Rào An Toàn Tuyệt Đối (SafetyGuard Engine)
* **Danh sách trắng bất khả xâm phạm (Hardcoded System Whitelist)**:
  * Toàn bộ các đường dẫn được bảo vệ bởi SIP (System Integrity Protection): `/System`, `/usr`, `/bin`, `/sbin`, `/private/var/vm` (swapfile, sleepimage của macOS kernel), `/private/var/db`, `/private/etc`, `/Library/Apple`.
  * Toàn bộ ứng dụng hệ thống của Apple: Các ứng dụng có Bundle ID `com.apple.*` trong `/System/Applications` (Finder, Safari, System Settings, Terminal...).
  * Dữ liệu bảo mật cốt lõi người dùng: `~/.ssh`, `~/Library/Keychains`, `~/Library/Accounts`.
* **Cơ chế khoá trên giao diện**:
  * Hiển thị biểu tượng khiên bảo vệ 🛡️ màu tím.
  * **Nút Xoá và Hộp kiểm bị VÔ HIỆU HÓA HOÀN TOÀN (Disabled)** đối với mọi tệp/app hệ thống để loại trừ 100% rủi ro làm hỏng macOS.

### 4. ♻️ Chuẩn Xoá An Toàn Apple (Safe Trash Protocol)
* 100% thao tác xoá được thực hiện thông qua `FileManager.default.trashItem(at:resultingItemURL:)`.
* Toàn bộ ứng dụng và tệp tàn dư được đưa nguyên vẹn vào **Thùng Rác (Trash)** của macOS.
* Người dùng có thể click chuột phải trong Trash và chọn **"Put Back" (Khôi phục)** về đúng vị trí cũ bất cứ lúc nào nếu lỡ tay.

---

## 💻 Yêu Cầu Hệ Thống
* **Hệ điều hành:** macOS 14.0 (Sonoma) hoặc macOS 15.0 (Sequoia) trở lên.
* **Kiến trúc chip:** Apple Silicon (M1, M2, M3, M4...) hoặc Intel x86_64.
* **Môi trường lập trình (để build):**
  * Xcode 15/16 hoặc Command Line Tools (`xcode-select --install`).
  * Swift 6.0+ (Dự án đã kiểm thử tương thích hoàn hảo trên Swift 6.3.3).

---

## 🛠️ Hướng Dẫn Build & Đóng Gói Từ A Đến Z

### Bước 1: Mở Terminal và di chuyển vào thư mục dự án
```bash
cd /Users/admin/Documents/MacAppCleaner
```

### Bước 2: Chạy kiểm thử tự động (Unit Tests)
Đảm bảo toàn bộ 11 bài kiểm thử tự động về cơ chế bảo vệ an toàn, dò tìm tàn dư và phân tích dung lượng đều vượt qua:
```bash
swift test
```
*Kết quả kỳ vọng: `Executed 11 tests, with 0 failures`.*

---

### Cách 1: Đóng gói thành File Ứng Dụng `.app` Độc Lập (Khuyến Nghị)

Dự án đã tích hợp sẵn script tự động hoá biên dịch bản tối ưu (Release), tạo bundle macOS chuẩn (`Info.plist`, `PkgInfo`) và ký mã Ad-hoc:

```bash
./scripts/build-app.sh
```

**Kết quả:** File ứng dụng `MacAppCleaner.app` sẽ được tạo ra tại thư mục:
```
/Users/admin/Documents/MacAppCleaner/build/MacAppCleaner.app
```

**Sử dụng:**
* Bạn có thể chạy ngay lập tức bằng lệnh:
  ```bash
  open build/MacAppCleaner.app
  ```
* Hoặc kéo `MacAppCleaner.app` vào thư mục `/Applications` của macOS để sử dụng lâu dài như mọi ứng dụng Mac tiêu chuẩn khác:
  ```bash
  cp -R build/MacAppCleaner.app /Applications/
  ```

---

### Cách 2: Chạy trực tiếp từ dòng lệnh (Dành cho Lập trình viên)
Nếu muốn khởi chạy nhanh trong lúc code hoặc debug:
```bash
swift run MacAppCleaner
```

---

### Cách 3: Mở & Phát Triển Bằng Xcode
Dự án sử dụng chuẩn **Swift Package Manager**, không cần cài đặt thêm CocoaPods hay Carthage:
```bash
open Package.swift
```
1. Xcode sẽ tự động nạp toàn bộ cấu trúc dự án.
2. Trên thanh toolbar đỉnh của Xcode, chọn Scheme **`MacAppCleaner`** và đích là **`My Mac`**.
3. Nhấn tổ hợp phím **`Cmd + R`** để Build & Run, hoặc **`Cmd + U`** để chạy bộ Test Suite.

---

## 🔑 Cấp Quyền Full Disk Access (FDA) để Quét Toàn Diện

Mặc định, cơ chế Sandbox và bảo mật của macOS giới hạn quyền truy cập vào các thư mục như `~/Library/Containers` (dữ liệu của các app tải từ App Store) hoặc `~/Library/Safari`. Để `MacAppCleaner` có thể quét sạch 100% tệp tàn dư:

1. Mở **Cài đặt hệ thống (System Settings)** trên máy Mac.
2. Vào mục **Quyền riêng tư & Bảo mật (Privacy & Security)** > **Toàn quyền truy cập ổ đĩa (Full Disk Access)**.
3. Bấm vào dấu `+`, chọn tệp `MacAppCleaner.app` và gạt công tắc sang trạng thái **Bật (Enabled)**.
*(Ứng dụng cũng có sẵn nút bấm mở nhanh cài đặt này ngay trên thanh banner đầu màn hình).*

---

## 📂 Cấu Trúc Mã Nguồn

```
MacAppCleaner/
├── Package.swift                                      # Manifest cấu hình Swift Package
├── scripts/
│   └── build-app.sh                                   # Script đóng gói thành MacAppCleaner.app
├── docs/
│   ├── superpowers/specs/2026-09-16-macappcleaner-design.md # Tài liệu đặc tả kỹ thuật chi tiết
│   └── superpowers/plans/2026-09-16-macappcleaner.md        # Kế hoạch thực thi 9 Tasks
├── Sources/
│   ├── MacAppCleaner/                                 # GUI Target (SwiftUI)
│   │   ├── MacAppCleanerApp.swift                     # Điểm khởi chạy @main App
│   │   ├── ViewModels/
│   │   │   ├── AppUninstallerViewModel.swift          # ViewModel quản lý gỡ app & quét tàn dư
│   │   │   └── DiskAnalyzerViewModel.swift            # ViewModel quản lý phân tích dung lượng
│   │   └── Views/
│   │       ├── MainView.swift                         # Layout chính NavigationSplitView
│   │       ├── Uninstaller/                           # Các màn hình gỡ ứng dụng
│   │       │   ├── AppListView.swift
│   │       │   ├── AppRowView.swift
│   │       │   ├── AppDetailView.swift
│   │       │   └── UninstallConfirmModal.swift
│   │       ├── DiskAnalyzer/                          # Các màn hình phân tích ổ đĩa
│   │       │   ├── DiskHierarchyView.swift
│   │       │   ├── DiskItemRowView.swift
│   │       │   └── QuickFilterView.swift
│   │       └── Components/
│   │           └── PermissionBannerView.swift
│   └── MacAppCleanerKit/                              # Core Logic Library Target
│       ├── Models/
│       │   ├── InstalledApp.swift                     # Model ứng dụng đã cài
│       │   ├── RelatedFile.swift                      # Model tệp tàn dư
│       │   ├── DiskItem.swift                         # Model phần tử cây ổ đĩa
│       │   └── FileCategory.swift                     # Phân loại tệp (Caches, Logs, Plist...)
│       ├── Services/
│       │   ├── AppDiscoveryService.swift              # Quét /Applications & đọc Mach-O binary
│       │   ├── ResidualScanner.swift                  # Thuật toán dò tìm tàn dư Pearcleaner
│       │   ├── DiskScannerService.swift               # Quét đệ quy dung lượng APFS đa luồng
│       │   ├── SafetyGuardService.swift               # Hàng rào Whitelist bảo vệ file hệ thống
│       │   └── TrashService.swift                     # Xoá an toàn qua FileManager.trashItem
│       └── Extensions/
│           └── ByteCountFormatter+Ext.swift           # Định dạng dung lượng chuẩn file macOS
└── Tests/
    └── MacAppCleanerTests/
        ├── SafetyGuardTests.swift                     # Kiểm tra bảo vệ SIP và ứng dụng Apple
        ├── ResidualScannerTests.swift                 # Kiểm tra quét tàn dư và từ chối tệp hệ thống
        ├── AppDiscoveryTests.swift                    # Kiểm tra quét ứng dụng thật trên máy
        ├── DiskScannerTests.swift                     # Kiểm tra tính toán phân cấp dung lượng
        └── ModelTests.swift                           # Kiểm tra tính toán dung lượng tổng
```

---

## ⚖️ Giấy Phép & Bản Quyền
Dự án được phát triển cho mục đích quản trị hệ thống và dọn dẹp máy tính cá nhân. Thiết kế tuân thủ nghiêm ngặt các nguyên tắc Apple Human Interface Guidelines và triết lý an toàn dữ liệu.
