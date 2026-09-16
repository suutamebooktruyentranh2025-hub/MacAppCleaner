import SwiftUI
import AppKit
import MacAppCleanerKit

struct QuickFilterView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanningLargeFiles {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("Đang quét các tệp lớn trên hệ thống...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.largeFiles.isEmpty && !viewModel.searchText.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("Không tìm thấy tệp lớn nào khớp với \"\(viewModel.searchText)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button("Xóa tìm kiếm") {
                        viewModel.searchText = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.largeFiles.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("Không tìm thấy tệp nào vượt ngưỡng dung lượng.")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Ổ đĩa của bạn hiện không có tệp nào chiếm dụng dung lượng quá lớn ở mức đã chọn.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.largeFiles, id: \.id) { (item: DiskItem) in
                        HStack(spacing: 12) {
                            // Real macOS Finder icon
                            AppIconView(
                                url: item.url,
                                size: 32,
                                fallbackSystemName: item.isDirectory ? "folder.fill" : "doc.fill"
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .semibold))

                                    if item.isProtected {
                                        Label("Bảo vệ hệ thống", systemImage: "shield.fill")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.purple)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                }

                                Text(item.url.path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .help(item.url.path)
                            }

                            Spacer()

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .help("Mở trong Finder")

                            Text(ByteCountFormatter.format(bytes: item.size))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)

                            Button(role: .destructive) {
                                Task {
                                    await viewModel.trashItem(item)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(item.isProtected ? Color.secondary : Color.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.isProtected)
                            .help(item.isProtected ? "Tệp hệ thống được bảo vệ — Không thể xóa" : "Chuyển tệp vào Thùng Rác")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
