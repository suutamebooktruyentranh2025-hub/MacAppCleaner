import SwiftUI
import MacAppCleanerKit

struct LibraryListView: View {
    @Bindable var viewModel: LibraryManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search & Sort Bar
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))

                        TextField("Tìm theo tên hoặc đường dẫn...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))

                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    // Sort Menu
                    Menu {
                        ForEach(LibrarySortOrder.allCases) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                if viewModel.sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .menuIndicator(.hidden)
                    .help("Sắp xếp danh sách thư viện")

                    Button {
                        Task {
                            await viewModel.loadLibraries(force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Quét và làm mới danh sách thư viện")
                    .disabled(viewModel.isLoading)
                }

                // Category Filter Pills ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(LibraryCategory.allCases) { cat in
                            Button {
                                viewModel.selectedCategory = cat
                            } label: {
                                HStack(spacing: 4) {
                                    Text(cat.rawValue)
                                        .font(.system(size: 11, weight: viewModel.selectedCategory == cat ? .semibold : .regular))

                                    let count = viewModel.count(for: cat)
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 0.5)
                                            .background(
                                                viewModel.selectedCategory == cat
                                                ? Color.white.opacity(0.25)
                                                : Color.secondary.opacity(0.12)
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    viewModel.selectedCategory == cat
                                    ? Color.accentColor
                                    : Color(nsColor: .controlBackgroundColor)
                                )
                                .foregroundStyle(viewModel.selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(viewModel.selectedCategory == cat ? 0 : 0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // List or Loading / Empty States
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Đang quét các thư viện và tiện ích...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredLibraries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Không tìm thấy thư viện nào")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if !viewModel.searchText.isEmpty {
                        Text("Thử xóa từ khóa tìm kiếm để xem tất cả.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedLibrary?.id },
                    set: { newId in
                        if let match = viewModel.filteredLibraries.first(where: { $0.id == newId }) {
                            Task {
                                await viewModel.selectLibrary(match)
                            }
                        }
                    }
                )) {
                    ForEach(viewModel.filteredLibraries) { lib in
                        LibraryRowView(
                            library: lib,
                            isSelected: viewModel.selectedLibrary?.id == lib.id
                        )
                        .tag(lib.id)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            // Bottom Count Summary
            Divider()
            HStack {
                Text("\(viewModel.filteredLibraries.count) mục")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tổng: \(ByteCountFormatter.format(bytes: viewModel.totalSize))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.04))
        }
    }
}
