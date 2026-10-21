import TransfloDomain

/// The three preset defaults available in General.
enum CompressionChoice: Hashable {
    case light, medium, strong

    init(_ goal: CompressionGoal) {
        switch goal {
        case .level(.light): self = .light
        case .level(.strong): self = .strong
        case .level(.medium), .targetBytes, .percentage: self = .medium
        }
    }

    var goal: CompressionGoal {
        switch self {
        case .light: .light
        case .medium: .medium
        case .strong: .strong
        }
    }
}
