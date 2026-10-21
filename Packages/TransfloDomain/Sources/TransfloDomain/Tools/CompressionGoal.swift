/// Strategy selection for either a quality preset or an upper bound on output bytes.
public enum CompressionGoal: Sendable, Hashable, Codable {
    case level(CompressionLevel)
    case targetBytes(Int64)
    /// Maximum output size as a percentage of each source file (1...99).
    case percentage(Int)

    public func byteBudget(originalBytes: Int64) -> Int64? {
        switch self {
        case .level: return nil
        case .targetBytes(let bytes): return bytes > 0 ? bytes : nil
        case .percentage(let percent):
            guard (1...99).contains(percent), originalBytes > 0 else { return nil }
            // Split before multiplication to stay safe for files approaching Int64.max.
            return max(1, originalBytes / 100 * Int64(percent) + originalBytes % 100 * Int64(percent) / 100)
        }
    }

    // Source-compatible spellings for existing preset callers.
    public static let light = CompressionGoal.level(.light)
    public static let medium = CompressionGoal.level(.medium)
    public static let strong = CompressionGoal.level(.strong)
}
