import AppKit
import DriftMapCore
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HeatmapPreviewViewModel {
    static let globalRecordKey = "global"
    static let standardCellSize: Double = 12

    var maxSampleCount: Int = 10_000
    var isCapturing: Bool = false
    var isOverlayActive: Bool = false
    var selectedRecordKey: String = HeatmapPreviewViewModel.globalRecordKey
    var selectedDisplayID: UInt32 = 0
    private(set) var focusedOverlayAppName: String?
    private(set) var focusedOverlayAppIdentifier: String?
    private(set) var samples: [CursorSample] = []
    private(set) var displays: [DisplayRecord] = []
    @ObservationIgnored private let overlayCoordinator = OverlayWindowCoordinator()
    @ObservationIgnored private var eventMonitors: [Any] = []
    private var captureTimer: Timer?
    private var focusedAppTimer: Timer?
    private var currentCanvasSize: CGSize = .zero
    private var lastRecordedPoint: CGPoint?
    private var lastRecordedDisplayID: UInt32?

    init() {
        refreshDisplays()
    }

    var sampleCount: Int {
        samples.count
    }

    var visibleSamples: [CursorSample] {
        samples.filter { sample in
            let matchesApp = selectedRecordKey == Self.globalRecordKey || sample.appIdentifier == selectedRecordKey
            let matchesDisplay = selectedDisplayID == 0 || sample.displayID == selectedDisplayID
            return matchesApp && matchesDisplay
        }
    }

    var visibleSampleCount: Int {
        visibleSamples.count
    }

    func overlaySamples(for displayID: UInt32) -> [CursorSample] {
        samples.filter { sample in
            let matchesApp = focusedOverlayAppIdentifier == nil || sample.appIdentifier == focusedOverlayAppIdentifier
            return matchesApp && sample.displayID == displayID
        }
    }

    var appRecords: [AppRecord] {
        let grouped = Dictionary(grouping: samples) { sample in
            sample.appIdentifier ?? "unknown"
        }

        return grouped.map { identifier, samples in
            AppRecord(
                identifier: identifier,
                name: samples.last?.appName ?? identifier,
                sampleCount: samples.count
            )
        }
        .sorted { left, right in
            if left.sampleCount == right.sampleCount {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }

            return left.sampleCount > right.sampleCount
        }
    }

    var selectedRecordTitle: String {
        if selectedRecordKey == Self.globalRecordKey {
            return "All apps"
        }

        return appRecords.first { $0.identifier == selectedRecordKey }?.name ?? selectedRecordKey
    }

    func startGlobalCapture(canvasSize: CGSize) {
        stopGlobalCapture()
        currentCanvasSize = canvasSize
        isCapturing = true

        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordCurrentMouseLocation(in: canvasSize)
            }
        }
        startEventMonitors()
    }

    func updateCaptureCanvasSize(_ canvasSize: CGSize) {
        currentCanvasSize = canvasSize

        guard isCapturing else {
            return
        }

        stopGlobalCapture()
        startGlobalCapture(canvasSize: canvasSize)
    }

    func stopGlobalCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        stopEventMonitors()
        isCapturing = false
        lastRecordedPoint = nil
        lastRecordedDisplayID = nil
    }

    func toggleCapture(canvasSize: CGSize) {
        if isCapturing {
            stopGlobalCapture()
        } else {
            startGlobalCapture(canvasSize: currentCanvasSize == .zero ? canvasSize : currentCanvasSize)
        }
    }

    func startOverlayMode() {
        refreshDisplays()
        startGlobalCapture(canvasSize: captureCanvasSize)
        startFocusedAppMonitoring()
        showOverlay()
    }

    func stopOverlayMode() {
        stopGlobalCapture()
        stopFocusedAppMonitoring()
        hideOverlay()
    }

    func toggleCaptureForOverlayMode() {
        toggleCapture(canvasSize: captureCanvasSize)
    }

    private var captureCanvasSize: CGSize {
        NSScreen.main?.frame.size ?? displays.first?.frame.size ?? CGSize(width: 1_440, height: 900)
    }

    private func recordCurrentMouseLocation(in canvasSize: CGSize) {
        let mouseLocation = NSEvent.mouseLocation

        guard !Self.isPointerOverOwnInterface(mouseLocation) else {
            lastRecordedPoint = nil
            return
        }

        guard let geometry = CaptureGeometry(mouseLocation: mouseLocation),
              let mappedPoint = geometry.map(mouseLocation: mouseLocation, canvasSize: canvasSize),
              let normalizedPoint = geometry.normalizedPoint(mouseLocation: mouseLocation)
        else {
            lastRecordedPoint = nil
            return
        }

        guard mappedPoint != lastRecordedPoint || geometry.displayID != lastRecordedDisplayID else {
            return
        }

        lastRecordedPoint = mappedPoint
        lastRecordedDisplayID = geometry.displayID
        record(
            point: mappedPoint,
            normalizedPoint: normalizedPoint,
            in: canvasSize,
            display: geometry.display,
            interactionType: .movement
        )
    }

    private func recordMouseEvent(interactionType: CursorInteractionType) {
        let mouseLocation = NSEvent.mouseLocation
        let canvasSize = currentCanvasSize

        guard !Self.isPointerOverOwnInterface(mouseLocation) else {
            return
        }

        guard let geometry = CaptureGeometry(mouseLocation: mouseLocation),
              let mappedPoint = geometry.map(mouseLocation: mouseLocation, canvasSize: canvasSize),
              let normalizedPoint = geometry.normalizedPoint(mouseLocation: mouseLocation)
        else {
            return
        }

        record(
            point: mappedPoint,
            normalizedPoint: normalizedPoint,
            in: canvasSize,
            display: geometry.display,
            interactionType: interactionType
        )
    }

    private func record(
        point: CGPoint,
        normalizedPoint: CGPoint,
        in canvasSize: CGSize,
        display: DisplayRecord,
        interactionType: CursorInteractionType
    ) {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return
        }

        guard point.x >= 0,
              point.y >= 0,
              point.x < canvasSize.width,
              point.y < canvasSize.height
        else {
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication

        samples.append(
            CursorSample(
                x: point.x,
                y: point.y,
                interactionType: interactionType,
                appIdentifier: frontmostApp?.bundleIdentifier ?? "unknown",
                appName: frontmostApp?.localizedName ?? "Unknown App",
                displayID: display.id,
                displayName: display.name,
                normalizedX: normalizedPoint.x,
                normalizedY: normalizedPoint.y
            )
        )

        if samples.count > maxSampleCount {
            samples.removeFirst(samples.count - maxSampleCount)
        }
    }

    private func startEventMonitors() {
        stopEventMonitors()

        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]

        addGlobalMonitor(mask: eventMask)
        addLocalMonitor(mask: eventMask)
    }

    private func addGlobalMonitor(mask: NSEvent.EventTypeMask) {
        guard let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            guard let interactionType = CursorInteractionType(event: event) else {
                return
            }

            Task { @MainActor in
                self?.recordMouseEvent(interactionType: interactionType)
            }
        }) else {
            return
        }

        eventMonitors.append(monitor)
    }

    private func addLocalMonitor(mask: NSEvent.EventTypeMask) {
        guard let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            guard let interactionType = CursorInteractionType(event: event) else {
                return event
            }

            Task { @MainActor in
                self?.recordMouseEvent(interactionType: interactionType)
            }

            return event
        }) else {
            return
        }

        eventMonitors.append(monitor)
    }

    private func stopEventMonitors() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }

    func clearSamples() {
        samples.removeAll(keepingCapacity: true)
        selectedRecordKey = Self.globalRecordKey
    }

    func clearFocusedAppSamples() {
        updateFocusedOverlayApp()

        guard let focusedOverlayAppIdentifier else {
            return
        }

        samples.removeAll { $0.appIdentifier == focusedOverlayAppIdentifier }
    }

    func toggleOverlay() {
        if isOverlayActive {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        refreshDisplays()
        startFocusedAppMonitoring()
        overlayCoordinator.show(displays: displays, viewModel: self)
        isOverlayActive = overlayCoordinator.isActive
    }

    func hideOverlay() {
        overlayCoordinator.hide()
        stopFocusedAppMonitoring()
        isOverlayActive = false
    }

    func refreshDisplays() {
        displays = NSScreen.screens.enumerated().map { index, screen in
            DisplayRecord(
                id: screen.displayID ?? UInt32(index),
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }

        if selectedDisplayID == 0 {
            selectedDisplayID = NSScreen.main?.displayID ?? displays.first?.id ?? 0
        }
    }

    private func startFocusedAppMonitoring() {
        stopFocusedAppMonitoring()
        updateFocusedOverlayApp()

        focusedAppTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFocusedOverlayApp()
            }
        }
    }

    private func stopFocusedAppMonitoring() {
        focusedAppTimer?.invalidate()
        focusedAppTimer = nil
        focusedOverlayAppIdentifier = nil
        focusedOverlayAppName = nil
    }

    private func updateFocusedOverlayApp() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.activationPolicy == .regular,
              frontmostApp.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            focusedOverlayAppIdentifier = nil
            focusedOverlayAppName = nil
            return
        }

        focusedOverlayAppIdentifier = frontmostApp.bundleIdentifier
        focusedOverlayAppName = frontmostApp.localizedName
    }

    /// True when the pointer sits over our own controls/settings windows so we don't
    /// record drift onto the DriftMap UI itself. The full-screen heatmap overlays are
    /// `NSPanel`s and are intentionally ignored — otherwise they'd block all capture.
    private static func isPointerOverOwnInterface(_ location: NSPoint) -> Bool {
        NSApp.windows.contains { window in
            window.isVisible && !(window is NSPanel) && window.frame.contains(location)
        }
    }
}

private extension NSScreen {
    var displayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }
}

private extension CursorInteractionType {
    init?(event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            self = .leftClick
        case .rightMouseDown:
            self = .rightClick
        case .otherMouseDown:
            self = .middleClick
        case .leftMouseDragged:
            self = .leftDrag
        case .rightMouseDragged:
            self = .rightDrag
        case .otherMouseDragged:
            self = .middleDrag
        case .scrollWheel:
            self = .scroll
        default:
            return nil
        }
    }
}

struct AppRecord: Identifiable, Equatable {
    let identifier: String
    let name: String
    let sampleCount: Int

    var id: String {
        identifier
    }
}

struct DisplayRecord: Identifiable, Equatable {
    let id: UInt32
    let name: String
    let frame: CGRect
    let visibleFrame: CGRect

    var label: String {
        "\(name) \(Int(frame.width))x\(Int(frame.height))"
    }
}

private struct CaptureGeometry {
    let display: DisplayRecord

    var displayID: UInt32 {
        display.id
    }

    init?(mouseLocation: CGPoint) {
        guard let match = NSScreen.screens.enumerated().compactMap({ index, screen -> DisplayRecord? in
            guard screen.frame.contains(mouseLocation) else {
                return nil
            }

            return DisplayRecord(
                id: screen.displayID ?? UInt32(index),
                name: screen.localizedName,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }).first else {
            return nil
        }

        self.display = match
    }

    func map(mouseLocation: CGPoint, canvasSize: CGSize) -> CGPoint? {
        guard canvasSize.width > 0,
              canvasSize.height > 0,
              let normalizedPoint = normalizedPoint(mouseLocation: mouseLocation)
        else {
            return nil
        }

        return CGPoint(
            x: normalizedPoint.x * canvasSize.width,
            y: normalizedPoint.y * canvasSize.height
        )
    }

    func normalizedPoint(mouseLocation: CGPoint) -> CGPoint? {
        guard display.frame.contains(mouseLocation)
        else {
            return nil
        }

        let xRatio = (mouseLocation.x - display.frame.minX) / display.frame.width
        let yRatio = (display.frame.maxY - mouseLocation.y) / display.frame.height

        return CGPoint(x: xRatio, y: yRatio)
    }
}
