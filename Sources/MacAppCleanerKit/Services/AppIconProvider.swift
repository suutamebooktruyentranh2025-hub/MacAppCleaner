import Foundation
import AppKit

public final class AppIconProvider: @unchecked Sendable {
    public static let shared = AppIconProvider()
    private let cache = NSCache<NSString, NSImage>()

    public init(countLimit: Int = 500) {
        cache.countLimit = countLimit
    }

    public func icon(for url: URL, size: CGSize = CGSize(width: 64, height: 64)) -> NSImage {
        let key = NSString(string: "\(url.path)_\(Int(size.width))x\(Int(size.height))")
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let baseIcon = NSWorkspace.shared.icon(forFile: url.path)
        let resized = NSImage(size: size)
        resized.lockFocus()
        baseIcon.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: baseIcon.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        cache.setObject(resized, forKey: key)
        return resized
    }

    public func icon(forPath path: String, size: CGSize = CGSize(width: 64, height: 64)) -> NSImage {
        icon(for: URL(fileURLWithPath: path), size: size)
    }

    public func clearCache() {
        cache.removeAllObjects()
    }
}
