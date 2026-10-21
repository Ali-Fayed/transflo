/// Identifier of a conversion engine, e.g. `imageio`, `ffmpeg`.
public struct EngineID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public var description: String { rawValue }
}
