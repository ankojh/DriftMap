import DriftMapCore
import SwiftUI

struct HeatmapPreview: View {
    @Bindable var viewModel: HeatmapPreviewViewModel

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let configuration = HeatmapConfiguration(
                canvasWidth: max(size.width, 1),
                canvasHeight: max(size.height, 1),
                cellSize: HeatmapPreviewViewModel.standardCellSize
            )
            let samples = viewModel.visibleSamples
            let cells = HeatmapAccumulator(configuration: configuration).cells(from: samples)

            Canvas { context, _ in
                drawGrid(in: &context, size: size, cellSize: HeatmapPreviewViewModel.standardCellSize)
                drawHeatmap(cells, in: &context, cellSize: HeatmapPreviewViewModel.standardCellSize)
                drawCursorPoints(samples, in: &context)
            }
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

    private func drawHeatmap(_ cells: [HeatmapCell], in context: inout GraphicsContext, cellSize: Double) {
        for cell in cells {
            let rect = CGRect(
                x: Double(cell.column) * cellSize,
                y: Double(cell.row) * cellSize,
                width: cellSize,
                height: cellSize
            )
            let color = Color(red: 1, green: 0.25 + (0.45 * (1 - cell.intensity)), blue: 0.08)
                .opacity(0.18 + (0.58 * cell.intensity))

            context.fill(Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 4), with: .color(color))
        }
    }

    private func drawCursorPoints(_ samples: [CursorSample], in context: inout GraphicsContext) {
        for sample in samples.suffix(300) {
            let rect = CGRect(x: sample.x - 2, y: sample.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.55)))
        }
    }
}
