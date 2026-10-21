/// One supported conversion and the engines that can perform it, in preference order.
public struct ConversionPath: Sendable, Hashable {
    public let source: FormatID
    public let target: FormatID
    public let engines: [EngineID]

    public init(source: FormatID, target: FormatID, engines: [EngineID]) {
        self.source = source
        self.target = target
        self.engines = engines
    }
}
