import DriftMapCore
import Foundation
import SwiftUI

struct HeatmapPreview: View {
    @Bindable var viewModel: HeatmapPreviewViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            HeatmapCanvas(samples: viewModel.visibleSamples, showsGrid: true, showsCursorPoints: true)
            .onAppear {
                viewModel.startGlobalCapture(canvasSize: size)
            }
            .onChange(of: size) { _, newSize in
                viewModel.updateCaptureCanvasSize(newSize)
            }
            .onDisappear {
                viewModel.stopGlobalCapture()
            }
        }
    }
}

struct HeatmapCanvas: View {
    let samples: [CursorSample]
    let showsGrid: Bool
    let showsCursorPoints: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let configuration = HeatmapConfiguration(
                canvasWidth: max(size.width, 1),
                canvasHeight: max(size.height, 1),
                cellSize: HeatmapPreviewViewModel.standardCellSize
            )
            let renderSamples = samples.map { sample in
                guard let normalizedX = sample.normalizedX,
                      let normalizedY = sample.normalizedY
                else {
                    return sample
                }

                return CursorSample(
                    x: normalizedX * size.width,
                    y: normalizedY * size.height,
                    timestamp: sample.timestamp,
                    interactionType: sample.interactionType,
                    appIdentifier: sample.appIdentifier,
                    appName: sample.appName,
                    displayID: sample.displayID,
                    displayName: sample.displayName,
                    normalizedX: normalizedX,
                    normalizedY: normalizedY
                )
            }

            Canvas { context, _ in
                if showsGrid {
                    drawGrid(in: &context, size: size, cellSize: HeatmapPreviewViewModel.standardCellSize)
                }

                drawHeatmap(
                    samples: renderSamples,
                    configuration: configuration,
                    in: &context,
                    cellSize: HeatmapPreviewViewModel.standardCellSize
                )

                drawMovePath(renderSamples, in: &context)

                if showsCursorPoints {
                    drawCursorPoints(renderSamples, in: &context)
                }
            }
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize, cellSize: Double) {
        var path = Path()

        stride(from: 0, through: size.width, by: cellSize).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        stride(from: 0, through: size.height, by: cellSize).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.stroke(path, with: .color(.secondary.opacity(0.14)), lineWidth: 1)
    }

    private func drawHeatmap(
        samples: [CursorSample],
        configuration: HeatmapConfiguration,
        in context: inout GraphicsContext,
        cellSize: Double
    ) {
        for interactionType in CursorInteractionType.allCases {
            let typedSamples = samples.filter { $0.interactionType == interactionType }
            let cells = HeatmapAccumulator(configuration: configuration).cells(from: typedSamples)

            for cell in cells {
                let rect = CGRect(
                    x: Double(cell.column) * cellSize,
                    y: Double(cell.row) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                let color = heatmapColor(for: interactionType, count: cell.count)

                context.fill(Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 4), with: .color(color))
            }
        }
    }

    /// Traces the cursor's actual route by connecting consecutive mouse-move points in
    /// the order they occurred, as a thin trail in the left-click color.
    private func drawMovePath(_ samples: [CursorSample], in context: inout GraphicsContext) {
        let moves = samples.filter { $0.interactionType == .movement }

        guard moves.count > 1 else {
            return
        }

        var path = Path()
        path.move(to: CGPoint(x: moves[0].x, y: moves[0].y))

        for move in moves.dropFirst() {
            path.addLine(to: CGPoint(x: move.x, y: move.y))
        }

        let color = ActionPalette.style(for: .leftClick).color(atLevel: 0.45).opacity(0.4)
        context.stroke(path, with: .color(color), lineWidth: 1)
    }

    private func drawCursorPoints(_ samples: [CursorSample], in context: inout GraphicsContext) {
        for sample in samples.suffix(300) {
            let rect = CGRect(x: sample.x - 2, y: sample.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: rect), with: .color(pointColor(for: sample.interactionType)))
        }
    }

    private func heatmapColor(for interactionType: CursorInteractionType, count: Int) -> Color {
        let style = ActionPalette.style(for: interactionType)
        return style.color(atLevel: style.shadeLevel(forCount: count))
    }

    private func pointColor(for interactionType: CursorInteractionType) -> Color {
        ActionPalette.style(for: interactionType).color(atLevel: 1)
    }
}

/// Each action gets its own well-separated hue so left / right / middle read distinctly
/// — left-click green vs right-click red being the most intuitive pair. The *depth* of a
/// cell is driven by how many times a spot was hit, mapped across a ramp of 20 shades,
/// so clicking the same place repeatedly keeps intensifying instead of saturating at the
/// first hit. Movement stays a neutral gray so it recedes behind the colored actions.
private enum ActionPalette {
    struct Style {
        /// Hue on the color wheel (0...1); `nil` renders as neutral gray (movement).
        let hue: Double?
        /// Hit count at which a cell approaches the deepest shade. Lower for deliberate,
        /// rare actions (clicks) so a handful of hits already reads as hot; higher for
        /// high-frequency streams (movement) so they don't blow out instantly.
        let saturationCount: Int

        /// Maps an absolute hit count onto one of 20 discrete shades (0...1).
        func shadeLevel(forCount count: Int) -> Double {
            guard count > 0 else {
                return 0
            }

            let raw = 1 - exp(-Double(count) / Double(saturationCount))
            return (raw * 20).rounded() / 20
        }

        /// Resolves a shade level into a color: deeper, more saturated, more opaque as
        /// the level (hit count) rises.
        func color(atLevel level: Double) -> Color {
            guard let hue else {
                return Color(white: 0.82 - (0.50 * level), opacity: 0.22 + (0.64 * level))
            }

            return Color(
                hue: hue,
                saturation: 0.45 + (0.50 * level),
                brightness: 0.98 - (0.30 * level),
                opacity: 0.32 + (0.63 * level)
            )
        }
    }

    static func style(for interactionType: CursorInteractionType) -> Style {
        switch interactionType {
        case .movement:
            Style(hue: nil, saturationCount: 6)

        // Clicks — distinct, intuitive hues: green / red / amber.
        case .leftClick:
            Style(hue: 0.34, saturationCount: 6)
        case .rightClick:
            Style(hue: 0.99, saturationCount: 6)
        case .middleClick:
            Style(hue: 0.11, saturationCount: 6)

        // Drags — cooler hues: blue / cyan / violet.
        case .leftDrag:
            Style(hue: 0.60, saturationCount: 24)
        case .rightDrag:
            Style(hue: 0.50, saturationCount: 24)
        case .middleDrag:
            Style(hue: 0.74, saturationCount: 24)

        // Scroll — magenta, clear of every other hue.
        case .scroll:
            Style(hue: 0.88, saturationCount: 24)
        }
    }
}
