import Foundation

public struct HeatmapCell: Equatable, Sendable, Identifiable {
    public let row: Int
    public let column: Int
    public let count: Int
    public let intensity: Double

    public var id: String {
        "\(row)-\(column)"
    }

    public init(row: Int, column: Int, count: Int, intensity: Double) {
        self.row = row
        self.column = column
        self.count = count
        self.intensity = intensity
    }
}
