import SwiftUI
import AppKit
import MacAppCleanerKit

struct AppDetailView: View {
    @Bindable var viewModel: AppUninstallerViewModel

    private var selectedAllResiduals: Bool {
        guard let app = viewModel.selectedApp, !app.residualFiles.isEmpty else { return false }
        return app.residualFiles.allSatisfy(\.isSelectedForDeletion)
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    var body: some View {
        if let app = viewModel.selectedApp {
            VStack(spacing: 0) {
                // Hero Header with ViewThatFits for 100% responsiveness at any width
                VStack(spacing: 0) {
                    ViewThatFits(in: .horizontal) {
                        // Wide Layout (side-by-side)
                        HStack(alignment: .top, spacing: 14) {
                            AppIconView(url: app.bundleURL, size: 60)

                            headerInfoSection(app: app)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            Spacer(minLength: 8)

                            totalSizeBadge(app: app)
                                .layoutPriority(2)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        // Compact Layout (wraps Total Size card below info)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                AppIconView(url: app.bundleURL, size: 48)
                                headerInfoSection(app: app)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            }

                            HStack {
                                Spacer()
                                totalSizeBadge(app: app)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // Residual Files List
                if viewModel.isScanningResiduals {
                    VStack(spacing: 14) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("Đang quét các tệp tàn dư (Caches, Application Support, Containers)...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Main App Bundle Row
                        Section("Ứng dụng gốc") {
                            HStack(spacing: 10) {
                                Image(systemName: "app.badge.checkmark")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gói ứng dụng (.app)")
                                        .font(.system(size: 13, weight: .medium))
                                    Text(app.bundleURL.path)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                                Spacer(minLength: 6)

                                Button {
                                    revealInFinder(app.bundleURL)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                                .help("Xem trong Finder")

                                Text(ByteCountFormatter.format(bytes: app.appSize))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.vertical, 4)
                        }

                        // Residuals Section
                        Section {
                            if app.residualFiles.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Không phát hiện thêm tệp tàn dư nào trên ổ đĩa.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ForEach(app.residualFiles) { file in
                                    HStack(spacing: 10) {
                                        Toggle("", isOn: Binding(
                                            get: { file.isSelectedForDeletion },
                                            set: { _ in viewModel.toggleResidualSelection(id: file.id) }
                                        ))
                                        .labelsHidden()
                                        .disabled(app.isSystemApp)

                                        Image(systemName: file.category.iconName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(categoryColor(for: file.category))
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.category.rawValue)
                                                .font(.system(size: 12, weight: .medium))
                                            Text(file.url.path)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .help(file.url.path)
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                                        Spacer(minLength: 6)

                                        Button {
                                            revealInFinder(file.url)
                                        } label: {
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Xem tệp này trong Finder")

                                        Text(ByteCountFormatter.format(bytes: file.size))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Tệp tàn dư phát hiện (\(app.residualFiles.count))")

                                Spacer()

                                if !app.residualFiles.isEmpty && !app.isSystemApp {
                                    Button(selectedAllResiduals ? "Bỏ chọn tất cả" : "Chọn tất cả") {
                                        viewModel.selectAllResiduals(select: !selectedAllResiduals)
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.link)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }

                Divider()

                // Action Footer with ViewThatFits for responsive wrapping
                VStack(spacing: 0) {
                    ViewThatFits(in: .horizontal) {
                        // Wide layout
                        HStack(spacing: 12) {
                            footerInfo(app: app)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            Spacer(minLength: 8)

                            actionButton(app: app)
                                .layoutPriority(2)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        // Compact layout (stacks button below)
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack {
                                footerInfo(app: app)
                                Spacer()
                            }
                            actionButton(app: app)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .sheet(isPresented: $viewModel.isShowingConfirmModal) {
                UninstallConfirmModal(viewModel: viewModel)
            }
            .alert(viewModel.alertTitle.isEmpty ? "Thông báo" : viewModel.alertTitle, isPresented: $viewModel.showErrorAlert) {
                if viewModel.needsFullDiskAccess {
                    Button("Mở Cài đặt hệ thống") {
                        PermissionManager.shared.openFullDiskAccessSettings()
                    }
                }
                Button("Đã hiểu", role: .cancel) {
                    viewModel.showErrorAlert = false
                }
            } message: {
                if let msg = viewModel.errorMessage {
                    Text(msg)
                }
            }
        } else {
            // Empty Selection State
            VStack(spacing: 16) {
                Image(systemName: "arrow.left.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text("Chọn một ứng dụng từ danh sách")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                Text("Xem chi tiết kích thước bộ cài và quét các tệp caches, cấu hình tàn dư liên quan.")
                    .font(.callout)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func headerInfoSection(app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(app.name)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let ver = app.version, !ver.isEmpty {
                    Text("v\(ver)")
                        .font(.system(size: 10.5, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if app.isSystemApp {
                    Label("Hệ thống", systemImage: "shield.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .fixedSize(horizontal: true, vertical: false)
                }

                if viewModel.isRunningApp {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Đang chạy")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Ứng dụng đang có tiến trình hoạt động (PID: \(viewModel.runningPIDs.map(String.init).joined(separator: ", ")))")
                }
            }

            if let bundleId = app.bundleIdentifier {
                Text(bundleId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text(app.architecture.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)

                if let date = app.installDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                }

                Button(action: {
                    revealInFinder(app.bundleURL)
                }) {
                    Label("Finder", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.link)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    @ViewBuilder
    private func totalSizeBadge(app: InstalledApp) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Tổng dung lượng")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(ByteCountFormatter.format(bytes: app.totalSize))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func footerInfo(app: InstalledApp) -> some View {
        if app.isSystemApp {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.purple)
                    .font(.callout)
                Text("Ứng dụng hệ thống macOS — Khóa gỡ bỏ an toàn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text("Dung lượng giải phóng:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(ByteCountFormatter.format(bytes: app.selectedSize))
                        .font(.callout.bold())
                        .foregroundStyle(.red)
                    Text("(\(1 + app.residualFiles.filter(\.isSelectedForDeletion).count) mục)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(app: InstalledApp) -> some View {
        Button(action: {
            viewModel.isShowingConfirmModal = true
        }) {
            Label("Gỡ bỏ hoàn toàn", systemImage: "trash.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(app.isSystemApp)
        .help(app.isSystemApp ? "Không thể gỡ bỏ ứng dụng hệ thống" : "Chuyển ứng dụng và tệp tàn dư vào Thùng rác")
    }

    private func categoryColor(for category: FileCategory) -> Color {
        switch category {
        case .application: return .blue
        case .caches: return .orange
        case .applicationSupport: return .indigo
        case .preferences: return .yellow
        case .logs: return .pink
        case .webKit: return .cyan
        case .savedState: return .purple
        case .containers: return .mint
        case .groupContainers: return .teal
        case .httpStorages: return .blue
        case .launchAgents: return .red
        case .other: return .secondary
        }
    }
}
