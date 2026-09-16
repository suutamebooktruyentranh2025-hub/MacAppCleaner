import SwiftUI
import AppKit
import MacAppCleanerKit

public struct AppIconView: View {
    let url: URL?
    let size: CGFloat
    var fallbackSystemName: String = "app.fill"
    var showShadow: Bool = true

    public init(
        url: URL?,
        size: CGFloat,
        fallbackSystemName: String = "app.fill",
        showShadow: Bool = true
    ) {
        self.url = url
        self.size = size
        self.fallbackSystemName = fallbackSystemName
        self.showShadow = showShadow
    }

    public var body: some View {
        Group {
            if let url = url {
                let iconImage = AppIconProvider.shared.icon(for: url, size: CGSize(width: size, height: size))
                Image(nsImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .shadow(color: showShadow ? Color.black.opacity(0.18) : Color.clear, radius: size * 0.05, x: 0, y: size * 0.03)
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.6, height: size * 0.6)
                    .frame(width: size, height: size)
                    .foregroundStyle(.secondary)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            }
        }
    }
}
