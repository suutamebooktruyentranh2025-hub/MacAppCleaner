import SwiftUI
import AppKit
import MacAppCleanerKit

struct DiskHierarchyView: View {
    @Bindable var viewModel: DiskAnalyzerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search and Controls Header
            VStack(spacing: 8) {
                // Top Row: Search Field + Scope Menu + Hidden Toggle + Back + Refresh
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))

                        TextField("Tìm kiếm tệp hoặc thư mục...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))

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

                    // Scan Scope Menu (User Home vs System Root)
                    Menu {
                        ForEach(DiskAnalyzerViewModel.ScanScope.allCases) { scope in
                            Button {
                                viewModel.setScope(scope)
                                Task {
                                    if viewModel.filterMode == .hierarchy {
                                        await viewModel.scan(scope: scope, force: false)
                                    } else {
                                        await viewModel.ensureLargeFilesScanned(force: false)
                                    }
                                }
                            } label: {
                                if viewModel.scanScope == scope {
                                    Label(scope.rawValue, systemImage: "checkmark")
                                } else {
                                    Label(scope.rawValue, systemImage: scope.icon)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.scanScope.icon)
                                .foregroundStyle(.blue)
                            Text(viewModel.scanScope.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    // Toggle Hidden Files (Available across all modes with ⌘⇧. shortcut)
                    Button(action: {
                        Task {
                            await viewModel.toggleHiddenFiles()
                        }
                    }) {
                        HStack(spacing: 5) {
                            if viewModel.isScanningHierarchy {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: viewModel.showHiddenFiles ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 11))
                            }
                            Text(viewModel.showHiddenFiles ? "Tệp ẩn: Bật" : "Tệp ẩn: Tắt")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 2)
                        .foregroundStyle(viewModel.showHiddenFiles ? Color.blue : Color.secondary)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.showHiddenFiles ? Color.blue : nil)
                    .controlSize(.small)
                    .help(viewModel.showHiddenFiles ? "Đang hiển thị tệp và thư mục ẩn (Nhấn hoặc dùng phím ⌘⇧. để tắt)" : "Đang ẩn tệp và thư mục ẩn (Nhấn hoặc dùng phím ⌘⇧. để bật)")
                    .keyboardShortcut(".", modifiers: [.command, .shift])

                    if !viewModel.navigationHistory.isEmpty && viewModel.filterMode == .hierarchy {
                        Button(action: {
                            Task {
                                await viewModel.navigateBack()
                            }
                        }) {
                            Label("Trở lại", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isScanningHierarchy)
                    }

                    Button(action: {
                        Task {
                            if viewModel.filterMode == .hierarchy {
                                await viewModel.scan(force: true)
                            } else {
                                await viewModel.ensureLargeFilesScanned(force: true)
                            }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isScanning)
                    .help(viewModel.isScanning ? "Đang trong quá trình quét..." : "Quét lại")
                }

                // Second Row: Mode Segmented Picker
                HStack {
                    Picker("Chế độ xem", selection: $viewModel.filterMode) {
                        ForEach(DiskAnalyzerViewModel.FilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 360)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Disk Storage Capacity Overview Card
            DiskStorageOverviewCard(
                storageInfo: viewModel.diskStorageInfo,
                scope: viewModel.scanScope
            )
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ZStack {
                hierarchyContentView
                    .opacity(viewModel.filterMode == .hierarchy ? 1 : 0)
                    .allowsHitTesting(viewModel.filterMode == .hierarchy)

                QuickFilterView(viewModel: viewModel)
                    .opacity(viewModel.filterMode != .hierarchy ? 1 : 0)
                    .allowsHitTesting(viewModel.filterMode != .hierarchy)
            }
            .task(id: viewModel.filterMode) {
                if viewModel.filterMode != .hierarchy {
                    await viewModel.ensureLargeFilesScanned(force: false)
                }
            }
        }
    }

    private var displayedChildren: [DiskItem] {
        guard let children = viewModel.currentRoot?.children else { return [] }
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return children }
        return children.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var hierarchyContentView: some View {
        if viewModel.isScanningHierarchy && viewModel.currentRoot == nil {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.1)
                Text("Đang phân tích cấu trúc & tính dung lượng thư mục...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let root = viewModel.currentRoot {
            VStack(alignment: .leading, spacing: 0) {
                breadcrumbBar(root: root)

                Divider()

                if displayedChildren.isEmpty && !viewModel.searchText.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Không tìm thấy tệp hoặc thư mục khớp với \"\(viewModel.searchText)\"")
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
                } else {
                    List(displayedChildren) { child in
                        DiskItemRowView(
                            item: child,
                            maxFolderSize: displayedChildren.first?.size ?? 1,
                            isSelected: viewModel.selectedItem?.id == child.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if child.isDirectory {
                                Task {
                                    await viewModel.navigateInto(item: child)
                                }
                            }
                        }
                        .onTapGesture {
                            viewModel.selectedItem = child
                        }
                    }
                    .listStyle(.inset)
                }

                // Bottom status bar
                Divider()
                HStack {
                    if viewModel.isScanningHierarchy {
                        ProgressView()
                            .controlSize(.mini)
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !viewModel.searchText.isEmpty {
                        Text("Tìm thấy \(displayedChildren.count) / \(root.children?.count ?? 0) mục")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(root.children?.count ?? 0) mục trong thư mục này")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Nhấn đúp vào thư mục để xem chi tiết bên trong")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.1)
                Text("Đang khởi tạo quét dung lượng ổ đĩa...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                if viewModel.currentRoot == nil {
                    await viewModel.scanHomeDirectory()
                }
            }
        }
    }

    @ViewBuilder
    private func breadcrumbBar(root: DiskItem) -> some View {
        HStack(spacing: 8) {
            // Quick 1-step Back Button
            if !viewModel.navigationHistory.isEmpty {
                Button {
                    Task {
                        await viewModel.navigateBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(5)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanningHierarchy)
                .help("Quay lại thư mục trước")
            }

            // Interactive Breadcrumb Trail
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.element.id) { index, item in
                            let isCurrent = (item.id == root.id)
                            let isFirst = (index == 0)

                            if !isFirst {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 1)
                            }

                            Button {
                                if !isCurrent {
                                    Task {
                                        await viewModel.navigateToBreadcrumb(item)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isFirst {
                                        Image(systemName: "house.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                                    } else {
                                        Image(systemName: isCurrent ? "folder.fill" : "folder")
                                            .font(.system(size: 11))
                                            .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                                    }

                                    Text(item.name)
                                        .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                                        .foregroundStyle(isCurrent ? Color.primary : .secondary)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    isCurrent
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isCurrent)
                            .help(isCurrent ? "Thư mục hiện tại: \(item.url.path)" : "Nhấn để quay về '\(item.name)'")
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: root.id) { _, newID in
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .trailing)
                    }
                }
            }

            Spacer(minLength: 8)

            // Open in Finder
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([root.url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Mở thư mục này trong Finder")

            Divider()
                .frame(height: 14)

            // Total Size
            Text(ByteCountFormatter.format(bytes: root.size))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06))
    }
}
