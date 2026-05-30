import Foundation

public struct CursorSample: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let timestamp: Date
    public let appIdentifier: String?
    public let appName: String?
    public let displayID: UInt32?
    public let displayName: String?

    public init(
        x: Double,
        y: Double,
        timestamp: Date = Date(),
        appIdentifier: String? = nil,
        appName: String? = nil,
        displayID: UInt32? = nil,
        displayName: String? = nil
    ) {
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.appIdentifier = appIdentifier
        self.appName = appName
        self.displayID = displayID
        self.displayName = displayName
    }
}
