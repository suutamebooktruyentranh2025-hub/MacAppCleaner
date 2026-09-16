import SwiftUI
import MacAppCleanerKit

struct UninstallConfirmModal: View {
    @Bindable var viewModel: AppUninstallerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPermissionGuide: Bool = false

    private var hasContainerResiduals: Bool {
        guard let app = viewModel.selectedApp else { return false }
        return app.residualFiles.contains { res in
            res.isSelectedForDeletion && (res.category == .containers || res.category == .groupContainers)
        }
    }

    var body: some View {
        if let app = viewModel.selectedApp {
            VStack(spacing: 20) {
                // Header with Real App Icon
                HStack(spacing: 16) {
                    AppIconView(url: app.bundleURL, size: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chuyển vào Thùng Rác?")
                            .font(.headline)
                        Text("Ứng dụng '\(app.name)' và các tệp tàn dư đã chọn sẽ được đưa an toàn vào Thùng Rác.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Breakdown Details Card
                VStack(spacing: 10) {
                    HStack {
                        Label("Gói ứng dụng (.app)", systemImage: "app.badge.checkmark")
                            .font(.caption)
                        Spacer()
                        Text(ByteCountFormatter.format(bytes: app.appSize))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    let selectedResiduals = app.residualFiles.filter(\.isSelectedForDeletion)
                    let residualBytes = selectedResiduals.reduce(0) { $0 + $1.size }

                    HStack {
                        Label("Tệp tàn dư (\(selectedResiduals.count) mục)", systemImage: "folder.badge.minus")
                            .font(.caption)
                        Spacer()
                        Text(ByteCountFormatter.format(bytes: residualBytes))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    HStack {
                        Text("Tổng dung lượng sẽ giải phóng:")
                            .font(.callout.bold())
                        Spacer()
                        Text(ByteCountFormatter.format(bytes: app.selectedSize))
                            .font(.callout.bold().monospaced())
                            .foregroundStyle(.red)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Running Process Alert
                if viewModel.isRunningApp {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ứng dụng đang hoạt động (PID: \(viewModel.runningPIDs.map(String.init).joined(separator: ", ")))")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text("Tiến trình đang chạy sẽ ngăn cản thao tác xóa. Vui lòng đóng ứng dụng trước khi tiếp tục.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            Task {
                                _ = await viewModel.terminateRunningApp()
                            }
                        } label: {
                            if viewModel.isTerminatingApp {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Thoát ứng dụng")
                                    .font(.caption.bold())
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .disabled(viewModel.isTerminatingApp)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Error Banner if deletion failed
                if let err = viewModel.errorMessage, viewModel.showErrorAlert {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Không thể gỡ bỏ:")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                                Text(err)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                isShowingPermissionGuide = true
                            } label: {
                                Label("Xem hướng dẫn cấp quyền", systemImage: "gearshape.fill")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
                            } label: {
                                Label("Mở trong Finder", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                        }
                        .padding(.leading, 28)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Pre-emptive Sandbox Container Warning if FDA is not granted
                if !PermissionManager.shared.hasFullDiskAccess() && hasContainerResiduals {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(.orange)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ứng dụng có tệp tàn dư Sandbox Containers")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text("Bạn chưa cấp quyền Full Disk Access. Gói .app vẫn sẽ được gỡ bỏ, nhưng một số tàn dư Sandbox có thể bị macOS giữ lại.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            isShowingPermissionGuide = true
                        } label: {
                            Text("Cấp quyền")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Safety Assurance Note
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                        .font(.title3)

                    Text("Các tệp sẽ được chuyển vào Thùng Rác của macOS thay vì xóa vĩnh viễn. Bạn có thể bấm 'Khôi phục' (Put Back) trong Thùng Rác bất cứ lúc nào.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Action Buttons
                HStack(spacing: 12) {
                    Button("Hủy bỏ") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(role: .destructive) {
                        Task {
                            let success = await viewModel.uninstallSelectedApp()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isUninstalling {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang chuyển vào Thùng Rác...")
                            }
                            .padding(.horizontal, 8)
                        } else {
                            Label("Chuyển vào Thùng Rác", systemImage: "trash.fill")
                                .padding(.horizontal, 8)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewModel.isUninstalling || viewModel.isTerminatingApp || viewModel.isRunningApp)
                }
            }
            .padding(24)
            .frame(width: 440)
            .sheet(isPresented: $isShowingPermissionGuide) {
                PermissionGuideModal()
            }
        }
    }
}
