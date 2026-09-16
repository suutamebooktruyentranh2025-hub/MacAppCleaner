import SwiftUI
import AppKit

final class SplitViewDelegateCoordinator: NSObject, NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            return max(proposedMinimumPosition, 200)
        }
        return proposedMinimumPosition
    }

    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        return false
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let minSize: CGSize
    let targetSize: CGSize
    private let coordinator = SplitViewDelegateCoordinator()

    init(
        minSize: CGSize = CGSize(width: 860, height: 560),
        targetSize: CGSize = CGSize(width: 1080, height: 680)
    ) {
        self.minSize = minSize
        self.targetSize = targetSize
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.minSize = minSize

            // Configure NSSplitViewController items to enforce minimum sidebar width
            configureSplitControllers(in: window.contentViewController)

            // Configure any NSSplitView delegates
            configureSplitViews(in: window.contentView)

            let current = window.frame
            if current.width < targetSize.width || current.height < targetSize.height {
                let screen = window.screen ?? NSScreen.main
                let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
                let finalWidth = min(targetSize.width, screenFrame.width - 40)
                let finalHeight = min(targetSize.height, screenFrame.height - 60)
                let newX = screenFrame.origin.x + (screenFrame.width - finalWidth) / 2
                let newY = screenFrame.origin.y + (screenFrame.height - finalHeight) / 2
                window.setFrame(
                    NSRect(x: newX, y: newY, width: finalWidth, height: finalHeight),
                    display: true,
                    animate: false
                )
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.minSize = minSize
            configureSplitControllers(in: window.contentViewController)
            configureSplitViews(in: window.contentView)
        }
    }

    private func configureSplitControllers(in controller: NSViewController?) {
        guard let controller = controller else { return }
        if let splitVC = controller as? NSSplitViewController {
            if !splitVC.splitViewItems.isEmpty {
                splitVC.splitViewItems[0].minimumThickness = 200
                splitVC.splitViewItems[0].maximumThickness = 280
                splitVC.splitViewItems[0].canCollapse = false
            }
        }
        for child in controller.children {
            configureSplitControllers(in: child)
        }
    }

    private func configureSplitViews(in view: NSView?) {
        guard let view = view else { return }
        if let splitView = view as? NSSplitView {
            if splitView.delegate == nil {
                splitView.delegate = coordinator
            }
        }
        for sub in view.subviews {
            configureSplitViews(in: sub)
        }
    }
}
