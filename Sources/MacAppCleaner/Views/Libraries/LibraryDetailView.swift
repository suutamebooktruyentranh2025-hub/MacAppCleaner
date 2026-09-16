import SwiftUI
import MacAppCleanerKit

struct LibraryDetailView: View {
    @Bindable var viewModel: LibraryManagerViewModel

    var body: some View {
        if let lib = viewModel.selectedLibrary {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Card
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(categoryColor(for: lib.category).opacity(0.15))
                                    .frame(width: 58, height: 58)

                                Image(systemName: lib.category.icon)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(categoryColor(for: lib.category))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(lib.name)
                                        .font(.title2.bold())
                                        .lineLimit(1)

                                    if let ver = lib.version {
                                        Text("v\(ver)")
                                            .font(.caption.monospaced().bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                            .foregroundStyle(.secondary)
                                    }

                                    if lib.isSystemProtected {
                                        Label("Hệ thống", systemImage: "shield.fill")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.purple)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    }
                                }

                                Text(lib.category.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let desc = lib.descriptionText, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .padding(.top, 2)
                                }
                            }

                            Spacer(minLength: 8)

                            // Size Badge
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Dung lượng")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(ByteCountFormatter.format(bytes: lib.size))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(16)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Path & Location Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VỊ TRÍ TRÊN ĐĨA")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(lib.installPath.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 8)

                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([lib.installPath])
                                } label: {
                                    Label("Finder", systemImage: "arrow.up.right.square")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Reverse Dependencies Section (if checked)
                        if viewModel.isCheckingDependencies {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang kiểm tra quan hệ phụ thuộc...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else if !viewModel.reverseDependencies.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("CÁC CÔNG CỤ ĐANG SỬ DỤNG THƯ VIỆN NÀY")
                                        .font(.caption.bold())
                                        .foregroundStyle(.orange)
                                }

                                FlowLayout(spacing: 6) {
                                    ForEach(viewModel.reverseDependencies, id: \.self) { dep in
                                        Text(dep)
                                            .font(.caption2.bold().monospaced())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Forward Dependencies Section (if present)
                        if !lib.dependencies.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CÁC THƯ VIỆN CẦN THIẾT (DEPENDENCIES)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                FlowLayout(spacing: 6) {
                                    ForEach(lib.dependencies, id: \.self) { dep in
                                        Text(dep)
                                            .font(.caption2.monospaced())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Capsule())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                Divider()

                // Sticky Bottom Action Bar
                HStack {
                    if lib.isSystemProtected {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.purple)
                            Text("Thư viện được macOS bảo vệ an toàn — Khóa gỡ bỏ.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dung lượng giải phóng:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(ByteCountFormatter.format(bytes: lib.size))
                                .font(.callout.bold().monospaced())
                                .foregroundStyle(.red)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        viewModel.showRemovalModal = true
                    } label: {
                        Label("Gỡ bỏ thư viện", systemImage: "trash.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(lib.isSystemProtected)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .sheet(isPresented: $viewModel.showRemovalModal) {
                LibraryRemovalModal(viewModel: viewModel)
            }
            .alert("Không thể gỡ bỏ thư viện", isPresented: $viewModel.showErrorAlert) {
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
                Image(systemName: "books.vertical.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary.opacity(0.6))
                Text("Chọn một thư viện từ danh sách")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
                Text("Xem chi tiết vị trí, kích thước đĩa và kiểm tra quan hệ phụ thuộc trước khi xóa.")
                    .font(.callout)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

// Lightweight flow layout for dependency tag capsules
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
