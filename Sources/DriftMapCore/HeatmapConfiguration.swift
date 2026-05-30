import Foundation

public struct HeatmapConfiguration: Equatable, Sendable {
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let cellSize: Double

    public init(canvasWidth: Double, canvasHeight: Double, cellSize: Double = 32) {
        precondition(canvasWidth > 0, "canvasWidth must be greater than zero")
        precondition(canvasHeight > 0, "canvasHeight must be greater than zero")
        precondition(cellSize > 0, "cellSize must be greater than zero")

        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.cellSize = cellSize
    }
}
