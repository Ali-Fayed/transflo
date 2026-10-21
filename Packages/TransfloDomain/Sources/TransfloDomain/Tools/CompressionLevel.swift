/// How hard Compress works: smaller files at lower quality as the level rises.
public enum CompressionLevel: Sendable, Hashable, CaseIterable, Codable {
    case light
    case medium
    case strong
}
