import SwiftUI
import MacAppCleanerKit

struct PermissionGuideModal: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasFDA: Bool = PermissionManager.shared.hasFullDiskAccess()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Cấp quyền truy cập hệ thống")
                        .font(.headline)
                    Text("Để gỡ bỏ sạch sẽ các ứng dụng bảo mật (App Store, Root) và tệp tàn dư ngầm, macOS yêu cầu bạn cấp quyền trong Cài đặt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Status Card 1: Full Disk Access
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Quyền truy cập toàn bộ đĩa (Full Disk Access)", systemImage: "internaldrive.fill")
                        .font(.subheadline.bold())

                    Spacer()

                    if hasFDA {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Đã cấp")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Chưa cấp")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Text("Cho phép MacAppCleaner quét và dọn dẹp các tệp caches, cấu hình tàn dư nằm sâu trong thư mục Containers và xóa app trong /Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        PermissionManager.shared.openFullDiskAccessSettings()
                    } label: {
                        Label("Mở Cài đặt Full Disk Access", systemImage: "gearshape.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        checkPermissions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Kiểm tra lại trạng thái quyền")
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Status Card 2: Automation (Finder)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Quyền Tự động hóa Finder (Automation)", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.subheadline.bold())

                    Spacer()
                }

                Text("Cho phép MacAppCleaner gửi yêu cầu chuyển vào Thùng Rác qua Finder, kích hoạt hộp thoại Touch ID / Mật khẩu Admin chuẩn khi xóa ứng dụng được bảo vệ.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    PermissionManager.shared.openAutomationSettings()
                } label: {
                    Label("Mở Cài đặt Tự động hóa", systemImage: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 3-step Guide instructions
            VStack(alignment: .leading, spacing: 7) {
                Text("Các bước thao tác:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 6) {
                    Text("1.")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Nhấn nút **'Mở Cài đặt Full Disk Access'** ở trên để đến thẳng Cài đặt macOS.")
                        .font(.caption)
                }

                HStack(alignment: .top, spacing: 6) {
                    Text("2.")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Tìm **MacAppCleaner** và gạt sang **BẬT** (ON). Nếu app đã có sẵn từ bản cũ nhưng không nhận, hãy chọn app rồi bấm dấu **'-'** để xóa, sau đó bấm **'+'** thêm lại.")
                        .font(.caption)
                }

                HStack(alignment: .top, spacing: 6) {
                    Text("3.")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Khi macOS hiện thông báo **'Quit & Reopen'** (hoặc bấm nút bên dưới), hãy **Thoát và mở lại** để macOS nạp quyền mới vào ứng dụng.")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Footer Actions
            HStack(spacing: 10) {
                Button {
                    checkPermissions()
                } label: {
                    Label("Kiểm tra lại quyền", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    _ = PermissionManager.shared.resetTCCPermissions()
                    checkPermissions()
                } label: {
                    Label("Làm mới TCC", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .help("Xóa cache quyền cũ trong macOS nếu gạt bật mà hệ thống không nhận")

                Spacer()

                if !hasFDA {
                    Button {
                        quitAndRelaunch()
                    } label: {
                        Label("Khởi động lại App", systemImage: "power")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .help("Thoát và mở lại để áp dụng quyền Full Disk Access của macOS")
                }

                Button("Đóng") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 480)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        withAnimation {
            hasFDA = PermissionManager.shared.hasFullDiskAccess()
        }
    }

    private func quitAndRelaunch() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}
