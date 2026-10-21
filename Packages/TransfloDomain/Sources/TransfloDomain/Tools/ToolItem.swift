import Foundation

/// One input to a tool run, with its recognized format.
public struct ToolItem: Sendable, Equatable {
    public let url: URL
    public let format: FormatDescriptor?

    public init(url: URL, format: FormatDescriptor?) {
        self.url = url
        self.format = format
    }
}
