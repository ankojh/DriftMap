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
    private(set) var samples: [CursorSample] = []
    private(set) var displays: [DisplayRecord] = []
    @ObservationIgnored private let overlayCoordinator = OverlayWindowCoordinator()
    private var captureTimer: Timer?
    private var currentCanvasSize: CGSize = .zero
    private var lastRecordedPoint: CGPoint?

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
            let matchesApp = selectedRecordKey == Self.globalRecordKey || sample.appIdentifier == selectedRecordKey
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
        isCapturing = false
        lastRecordedPoint = nil
    }

    func toggleCapture(canvasSize: CGSize) {
        if isCapturing {
            stopGlobalCapture()
        } else {
            startGlobalCapture(canvasSize: currentCanvasSize == .zero ? canvasSize : currentCanvasSize)
        }
    }

    private func recordCurrentMouseLocation(in canvasSize: CGSize) {
        let mouseLocation = NSEvent.mouseLocation
        guard let geometry = CaptureGeometry(mouseLocation: mouseLocation),
              let mappedPoint = geometry.map(mouseLocation: mouseLocation, canvasSize: canvasSize),
              let normalizedPoint = geometry.normalizedPoint(mouseLocation: mouseLocation)
        else {
            lastRecordedPoint = nil
            return
        }

        guard mappedPoint != lastRecordedPoint || geometry.displayID != selectedDisplayID else {
            return
        }

        lastRecordedPoint = mappedPoint
        record(point: mappedPoint, normalizedPoint: normalizedPoint, in: canvasSize, display: geometry.display)
    }

    private func record(point: CGPoint, normalizedPoint: CGPoint, in canvasSize: CGSize, display: DisplayRecord) {
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

    func clearSamples() {
        samples.removeAll(keepingCapacity: true)
        selectedRecordKey = Self.globalRecordKey
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
        overlayCoordinator.show(displays: displays, viewModel: self)
        isOverlayActive = overlayCoordinator.isActive
    }

    func hideOverlay() {
        overlayCoordinator.hide()
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
}

private extension NSScreen {
    var displayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
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
