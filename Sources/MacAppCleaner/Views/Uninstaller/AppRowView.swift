import SwiftUI
import MacAppCleanerKit

struct AppRowView: View {
    let app: InstalledApp
    let isSelected: Bool
    @State private var isHovered = false

    private var archColor: Color {
        switch app.architecture {
        case .arm64: return .green
        case .intel: return .orange
        case .universal: return .blue
        case .unknown: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Real macOS application icon
            AppIconView(url: app.bundleURL, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if app.isSystemApp {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : .purple)
                            .help("Ứng dụng hệ thống macOS (Được bảo vệ)")
                    }
                }

                HStack(spacing: 4) {
                    // Architecture Badge
                    Text(app.architecture.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.2) : archColor.opacity(0.12))
                        .foregroundStyle(isSelected ? .white : archColor)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .fixedSize(horizontal: true, vertical: false)

                    if let ver = app.version, !ver.isEmpty {
                        Text("v\(ver)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            Text(ByteCountFormatter.format(bytes: app.totalSize))
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
