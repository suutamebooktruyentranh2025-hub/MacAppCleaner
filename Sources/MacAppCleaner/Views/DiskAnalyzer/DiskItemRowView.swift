import SwiftUI
import AppKit
import MacAppCleanerKit

struct DiskItemRowView: View {
    let item: DiskItem
    let maxFolderSize: Int64
    let isSelected: Bool
    @State private var isHovered = false

    var relativeRatio: Double {
        guard maxFolderSize > 0 else { return 0 }
        return min(1.0, Double(item.size) / Double(maxFolderSize))
    }

    private var barGradient: LinearGradient {
        if item.isProtected {
            return LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
        } else if relativeRatio > 0.6 {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        } else if relativeRatio > 0.25 {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Real macOS Finder file/folder icon
            AppIconView(
                url: item.url,
                size: 26,
                fallbackSystemName: item.isDirectory ? "folder.fill" : "doc.fill",
                showShadow: false
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    if item.isProtected {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : .purple)
                            .help("Tệp hệ thống được bảo vệ — Không cho phép xoá")
                    }

                    if item.isHidden {
                        Text("Ẩn")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            .clipShape(Capsule())
                    }
                }

                // Relative size bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(isSelected ? LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .leading, endPoint: .trailing) : barGradient)
                            .frame(width: max(4, geo.size.width * relativeRatio), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            if isHovered && !isSelected {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Mở trong Finder")
            }

            Text(ByteCountFormatter.format(bytes: item.size))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .secondary)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
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
