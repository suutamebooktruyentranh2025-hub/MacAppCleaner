import SwiftUI
import MacAppCleanerKit

struct LibraryRemovalModal: View {
    @Bindable var viewModel: LibraryManagerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let lib = viewModel.selectedLibrary {
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(categoryColor(for: lib.category).opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: lib.category.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(categoryColor(for: lib.category))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Gỡ bỏ thư viện?")
                            .font(.headline)
                        Text("Xác nhận loại bỏ '\(lib.name)' khỏi hệ thống.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Breakdown Card
                VStack(spacing: 8) {
                    HStack {
                        Text("Tên thư viện:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lib.name)
                            .font(.caption.bold())
                    }

                    if let ver = lib.version {
                        HStack {
                            Text("Phiên bản:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ver)
                                .font(.caption.monospaced())
                        }
                    }

                    HStack {
                        Text("Phân loại:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lib.category.rawValue)
                            .font(.caption)
                    }

                    Divider()

                    HStack {
                        Text("Dung lượng giải phóng:")
                            .font(.callout.bold())
                        Spacer()
                        Text(ByteCountFormatter.format(bytes: lib.size))
                            .font(.callout.bold().monospaced())
                            .foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Reverse Dependencies Warning Card (if any)
                if !viewModel.reverseDependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.headline)
                            Text("Cảnh báo phụ thuộc đảo (Reverse Dependencies):")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }

                        Text("Các gói/công cụ sau đang sử dụng '\(lib.name)':")
                            .font(.caption2)
                            .foregroundStyle(.primary)

                        Text(viewModel.reverseDependencies.joined(separator: ", "))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        Text("Gỡ bỏ có thể khiến các công cụ trên bị gián đoạn hoạt động.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Safety Mode Card
                HStack(spacing: 10) {
                    if isFilesystemItem(category: lib.category) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.title3)

                        Text("Tệp sẽ được chuyển vào Thùng Rác của macOS thay vì xóa vĩnh viễn. Bạn có thể bấm 'Khôi phục' (Put Back) bất cứ lúc nào.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)

                        Text("Hệ thống sẽ thực thi lệnh gỡ cài đặt chính thức của trình quản lý gói để đảm bảo tính toàn vẹn.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06))
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
                            let success = await viewModel.removeSelectedLibrary()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isRemoving {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang gỡ bỏ...")
                            }
                            .padding(.horizontal, 8)
                        } else {
                            Label("Xác nhận gỡ bỏ", systemImage: "trash.fill")
                                .padding(.horizontal, 8)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isRemoving || lib.isSystemProtected)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
            .frame(width: 440)
        }
    }

    private func isFilesystemItem(category: LibraryCategory) -> Bool {
        category == .frameworks || category == .audioPlugins || category == .quickLook
    }

    private func categoryColor(for category: LibraryCategory) -> Color {
        switch category {
        case .frameworks: return .blue
        case .audioPlugins: return .purple
        case .homebrew: return .orange
        case .node: return .green
        case .python: return .yellow
        case .quickLook: return .teal
        case .aiModels: return .indigo
        case .all: return .secondary
        }
    }
}
