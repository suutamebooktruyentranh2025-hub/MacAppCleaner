import SwiftUI
import MacAppCleanerKit

struct AppListView: View {
    @Bindable var viewModel: AppUninstallerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search and Control Header
            VStack(spacing: 10) {
                // Top Row: Search Field + Sort Menu + Refresh Button
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))

                        TextField("Tìm theo tên hoặc bundle ID...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))

                        if !viewModel.searchText.isEmpty {
                            Button(action: { viewModel.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                    Menu {
                        Section("Sắp xếp theo") {
                            ForEach(AppSortOrder.allCases) { order in
                                Button {
                                    viewModel.sortOrder = order
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if viewModel.sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .frame(width: 20, height: 20)
                    .help("Sắp xếp danh sách")

                    Button {
                        Task {
                            await viewModel.loadApps(force: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Làm mới danh sách ứng dụng")
                    .disabled(viewModel.isLoading)
                }

                // Second Row: Responsive Filter Pills (Never clips text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(AppFilterCategory.allCases) { category in
                            Button {
                                viewModel.selectedCategory = category
                            } label: {
                                HStack(spacing: 4) {
                                    if viewModel.selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    Text(category.rawValue)
                                        .font(.system(size: 11, weight: viewModel.selectedCategory == category ? .semibold : .regular))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    viewModel.selectedCategory == category
                                    ? Color.accentColor
                                    : Color(nsColor: .controlBackgroundColor)
                                )
                                .foregroundStyle(viewModel.selectedCategory == category ? Color.white : Color.primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.selectedCategory == category ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }

                // Stats Bar
                HStack {
                    Text("\(viewModel.filteredApps.count) ứng dụng")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    let totalFilteredBytes = viewModel.filteredApps.reduce(0) { $0 + $1.totalSize }
                    Text(ByteCountFormatter.format(bytes: totalFilteredBytes))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // List Content
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("Đang quét các ứng dụng trên Mac...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("Không tìm thấy ứng dụng phù hợp")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if !viewModel.searchText.isEmpty || viewModel.selectedCategory != .all {
                        Button("Xóa bộ lọc") {
                            viewModel.searchText = ""
                            viewModel.selectedCategory = .all
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredApps) { app in
                    AppRowView(app: app, isSelected: viewModel.selectedApp?.id == app.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await viewModel.selectApp(app)
                            }
                        }
                }
                .listStyle(.inset)
            }
        }
        .task {
            if viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
    }
}
