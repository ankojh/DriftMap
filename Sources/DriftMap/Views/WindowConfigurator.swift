import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.configure(window: nsView.window)
        }
    }

    @MainActor
    final class Coordinator {
        private var hasConfiguredWindow = false
        private weak var configuredWindow: NSWindow?
        private var positionTimer: Timer?

        func configure(window: NSWindow?) {
            guard let window else {
                return
            }

            configuredWindow = window

            guard !hasConfiguredWindow else {
                positionWindow(window)
                return
            }

            let size = NSSize(width: 104, height: 58)

            hasConfiguredWindow = true
            window.styleMask = [.borderless]
            window.backgroundColor = .clear
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.hasShadow = false
            window.isMovableByWindowBackground = false
            window.isOpaque = false
            window.level = .floating
            window.setContentSize(size)
            positionWindow(window)

            positionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self, weak window] _ in
                guard let window else {
                    return
                }

                Task { @MainActor in
                    self?.positionWindow(window)
                }
            }
        }

        private func positionWindow(_ window: NSWindow) {
            let size = NSSize(width: 104, height: 58)
            let monitorFrame = Self.activeMonitorVisibleFrame(for: window)

            let origin = NSPoint(
                x: monitorFrame.maxX - size.width - 12,
                y: monitorFrame.minY + 12
            )

            window.setFrame(NSRect(origin: origin, size: size), display: true)
        }

        private static func activeMonitorVisibleFrame(for window: NSWindow) -> NSRect {
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { $0.frame.contains(mouseLocation) }?.visibleFrame
                ?? window.screen?.visibleFrame
                ?? NSScreen.main?.visibleFrame
                ?? window.frame
        }
    }
}
