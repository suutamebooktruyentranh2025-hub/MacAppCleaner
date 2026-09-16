import SwiftUI
import AppKit
import MacAppCleanerKit

@main
struct MacAppCleanerApp: App {
    init() {
        setAppIcon()
    }

    private func setAppIcon() {
        if let image = AppBrandIcon.image {
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
