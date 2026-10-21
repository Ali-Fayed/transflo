/// Document-content gradient tokens. They keep their colors in both system appearances.
public enum BackgroundPreset: String, Sendable, Hashable, CaseIterable {
    case lagoon, moss, linen, glacier, slate, amber, ink, seaGlass

    public var colors: (start: String, end: String) {
        switch self {
        case .lagoon: ("#126D66", "#B7DDD2")
        case .moss: ("#244E3A", "#C9D9A5")
        case .linen: ("#A58A68", "#F0E5D1")
        case .glacier: ("#345B77", "#C9E3E5")
        case .slate: ("#283A42", "#9CB3B7")
        case .amber: ("#9A5E24", "#E8C78C")
        case .ink: ("#15272A", "#486F73")
        case .seaGlass: ("#3F8A82", "#D1E5D4")
        }
    }

    public var angleDegrees: Double {
        switch self {
        case .lagoon: 35
        case .moss: 125
        case .linen: 20
        case .glacier: 60
        case .slate: 130
        case .amber: 30
        case .ink: 110
        case .seaGlass: 45
        }
    }
}
