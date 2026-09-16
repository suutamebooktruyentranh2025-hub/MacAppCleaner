import SwiftUI
import AppKit
import MacAppCleanerKit

enum NavigationSection: String, CaseIterable, Identifiable {
    case uninstaller = "Gỡ ứng dụng"
    case diskAnalyzer = "Dung lượng ổ đĩa"
    case libraries = "Thư viện & Tiện ích"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .uninstaller: return "trash.fill"
        case .diskAnalyzer: return "internaldrive.fill"
        case .libraries: return "books.vertical.fill"
        }
    }
    var color: Color {
        switch self {
        case .uninstaller: return .blue
        case .diskAnalyzer: return .orange
        case .libraries: return .purple
        }
    }
}

struct MainView: View {
    @State private var selectedSection: NavigationSection = .uninstaller
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var uninstallerVM = AppUninstallerViewModel()
    @State private var diskVM = DiskAnalyzerViewModel()
    @State private var libraryVM = LibraryManagerViewModel()
    @State private var isShowingPermissionGuide: Bool = false

    private var appLogoImage: NSImage? {
        AppBrandIcon.image
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // App Branding Header with ample top padding to clear traffic lights
                HStack(spacing: 8) {
                    if let logo = appLogoImage {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    } else {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("MacAppCleaner")
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text("v1.0")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        Text("Dọn dẹp & Tối ưu Mac")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.top, 42)
                .padding(.bottom, 10)

                Divider()

                // Navigation Items List
                List(NavigationSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 6) {
                            Label {
                                Text(section.rawValue)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                            } icon: {
                                Image(systemName: section.icon)
                                    .foregroundStyle(section.color)
                            }

                            Spacer(minLength: 4)

                            if section == .uninstaller && !uninstallerVM.apps.isEmpty {
                                Text("\(uninstallerVM.apps.count)")
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            if section == .diskAnalyzer, let info = diskVM.diskStorageInfo {
                                Text(info.formattedAvailable)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            if section == .libraries && !libraryVM.libraries.isEmpty {
                                Text("\(libraryVM.libraries.count)")
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Spacer(minLength: 0)

                // Sidebar Footer Info
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "applelogo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("macOS Utility Suite")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)

                    Button {
                        isShowingPermissionGuide = true
                    } label: {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Xem quyền hệ thống & Hướng dẫn cấp Full Disk Access")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.04))
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } detail: {
            VStack(spacing: 0) {
                PermissionBannerView()

                ZStack {
                    HSplitView {
                        AppListView(viewModel: uninstallerVM)
                            .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)

                        AppDetailView(viewModel: uninstallerVM)
                            .frame(minWidth: 380)
                    }
                    .opacity(selectedSection == .uninstaller ? 1 : 0)
                    .allowsHitTesting(selectedSection == .uninstaller)

                    DiskHierarchyView(viewModel: diskVM)
                        .opacity(selectedSection == .diskAnalyzer ? 1 : 0)
                        .allowsHitTesting(selectedSection == .diskAnalyzer)

                    LibraryManagerView(viewModel: libraryVM)
                        .opacity(selectedSection == .libraries ? 1 : 0)
                        .allowsHitTesting(selectedSection == .libraries)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 560)
        .background(WindowConfigurator(minSize: CGSize(width: 860, height: 560), targetSize: CGSize(width: 1080, height: 680)))
        .sheet(isPresented: $isShowingPermissionGuide) {
            PermissionGuideModal()
        }
    }
}
