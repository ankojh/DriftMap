import Foundation

public struct HeatmapAccumulator: Sendable {
    public let configuration: HeatmapConfiguration

    public init(configuration: HeatmapConfiguration) {
        self.configuration = configuration
    }

    public func cells(from samples: [CursorSample]) -> [HeatmapCell] {
        var counts: [CellKey: Int] = [:]

        for sample in samples where contains(sample) {
            let column = min(Int(sample.x / configuration.cellSize), columnCount - 1)
            let row = min(Int(sample.y / configuration.cellSize), rowCount - 1)
            counts[CellKey(row: row, column: column), default: 0] += 1
        }

        let maxCount = counts.values.max() ?? 0

        return counts
            .map { key, count in
                HeatmapCell(
                    row: key.row,
                    column: key.column,
                    count: count,
                    intensity: maxCount == 0 ? 0 : Double(count) / Double(maxCount)
                )
            }
            .sorted { left, right in
                if left.row == right.row {
                    return left.column < right.column
                }

                return left.row < right.row
            }
    }

    public var rowCount: Int {
        Int(ceil(configuration.canvasHeight / configuration.cellSize))
    }

    public var columnCount: Int {
        Int(ceil(configuration.canvasWidth / configuration.cellSize))
    }

    private func contains(_ sample: CursorSample) -> Bool {
        sample.x >= 0 &&
            sample.y >= 0 &&
            sample.x < configuration.canvasWidth &&
            sample.y < configuration.canvasHeight
    }
}

private struct CellKey: Hashable {
    let row: Int
    let column: Int
}
