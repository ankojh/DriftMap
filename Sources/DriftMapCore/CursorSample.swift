import Foundation

public enum CursorInteractionType: String, Sendable, CaseIterable {
    case movement
    case leftClick
    case rightClick
    case middleClick
    case leftDrag
    case rightDrag
    case middleDrag
    case scroll
}

public struct CursorSample: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let timestamp: Date
    public let interactionType: CursorInteractionType
    public let appIdentifier: String?
    public let appName: String?
    public let displayID: UInt32?
    public let displayName: String?
    public let normalizedX: Double?
    public let normalizedY: Double?

    public init(
        x: Double,
        y: Double,
        timestamp: Date = Date(),
        interactionType: CursorInteractionType = .movement,
        appIdentifier: String? = nil,
        appName: String? = nil,
        displayID: UInt32? = nil,
        displayName: String? = nil,
        normalizedX: Double? = nil,
        normalizedY: Double? = nil
    ) {
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.interactionType = interactionType
        self.appIdentifier = appIdentifier
        self.appName = appName
        self.displayID = displayID
        self.displayName = displayName
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }
}
