/// Stable identifier of a file format, e.g. `png`, `heic`, `mp4` (always lowercase).
public struct FormatID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public var description: String { rawValue }
}
