import SwiftUI
import AppKit

@main
struct MacAppCleanerApp: App {
    init() {
        setAppIcon()
    }

    private func setAppIcon() {
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = image
        } else if let icnsURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                  let image = NSImage(contentsOf: icnsURL) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 700)
        .windowResizability(.contentMinSize)
    }
}
