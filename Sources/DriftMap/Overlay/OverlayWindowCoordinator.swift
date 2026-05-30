import AppKit
import SwiftUI

@MainActor
final class OverlayWindowCoordinator {
    private var panels: [UInt32: NSPanel] = [:]

    var isActive: Bool {
        !panels.isEmpty
    }

    func show(displays: [DisplayRecord], viewModel: HeatmapPreviewViewModel) {
        hide()

        for display in displays {
            let panel = NSPanel(
                contentRect: display.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(
                rootView: HeatmapOverlayView(viewModel: viewModel, displayID: display.id)
            )
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isFloatingPanel = false
            panel.isOpaque = false
            panel.level = .statusBar
            panel.setFrame(display.frame, display: true)
            panel.orderFrontRegardless()

            panels[display.id] = panel
        }
    }

    func hide() {
        for panel in panels.values {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }

        panels.removeAll()
    }
}
