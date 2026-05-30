import Testing
import Foundation
@testable import DriftMapCore

@Test func bucketsSamplesIntoCells() {
    let accumulator = HeatmapAccumulator(
        configuration: HeatmapConfiguration(canvasWidth: 100, canvasHeight: 100, cellSize: 25)
    )

    let cells = accumulator.cells(from: [
        CursorSample(x: 1, y: 1),
        CursorSample(x: 24, y: 24),
        CursorSample(x: 26, y: 1)
    ])

    #expect(cells == [
        HeatmapCell(row: 0, column: 0, count: 2, intensity: 1),
        HeatmapCell(row: 0, column: 1, count: 1, intensity: 0.5)
    ])
}

@Test func ignoresSamplesOutsideCanvas() {
    let accumulator = HeatmapAccumulator(
        configuration: HeatmapConfiguration(canvasWidth: 100, canvasHeight: 100, cellSize: 25)
    )

    let cells = accumulator.cells(from: [
        CursorSample(x: -1, y: 10),
        CursorSample(x: 10, y: 100),
        CursorSample(x: 99, y: 99)
    ])

    #expect(cells == [
        HeatmapCell(row: 3, column: 3, count: 1, intensity: 1)
    ])
}

@Test func exposesGridDimensions() {
    let accumulator = HeatmapAccumulator(
        configuration: HeatmapConfiguration(canvasWidth: 101, canvasHeight: 76, cellSize: 25)
    )

    #expect(accumulator.columnCount == 5)
    #expect(accumulator.rowCount == 4)
}
