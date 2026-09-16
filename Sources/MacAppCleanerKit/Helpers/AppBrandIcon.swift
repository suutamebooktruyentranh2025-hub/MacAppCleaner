import Foundation
import AppKit

public enum AppBrandIcon {
    /// Safely loads the app brand icon across macOS .app bundles, system lookups, and dev builds without throwing fatalErrors.
    public static var image: NSImage? {
        // 1. AppKit system application icon (works automatically when CFBundleIconFile is set in Info.plist)
        if let appIcon = NSImage(named: NSImage.applicationIconName), appIcon.isValid {
            return appIcon
        }
        if let namedIcon = NSImage(named: "AppIcon"), namedIcon.isValid {
            return namedIcon
        }

        // 2. Direct lookup in main bundle resources (Contents/Resources/AppIcon.png or AppIcon.icns)
        if let pngURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: pngURL), img.isValid {
            return img
        }
        if let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: icnsURL), img.isValid {
            return img
        }

        // 3. Fallback for CLI development (swift run) from repository source
        let devPaths = [
            "Sources/MacAppCleaner/Resources/AppIcon.png",
            "Sources/MacAppCleaner/Resources/AppIcon.icns"
        ]
        for relPath in devPaths {
            let url = URL(fileURLWithPath: relPath)
            if FileManager.default.fileExists(atPath: url.path),
               let img = NSImage(contentsOf: url), img.isValid {
                return img
            }
        }

        return nil
    }
}
