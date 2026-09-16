import SwiftUI
import MacAppCleanerKit

struct LibraryRowView: View {
    let library: InstalledLibrary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: library.category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            // Name & Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(library.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if let ver = library.version, !ver.isEmpty {
                        Text("v\(ver)")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    if library.isSystemProtected {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                            .help("Được bảo vệ bởi hệ thống macOS")
                    }
                }

                Text(library.category.rawValue)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Disk Size
            Text(ByteCountFormatter.format(bytes: library.size))
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private var categoryColor: Color {
        switch library.category {
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
