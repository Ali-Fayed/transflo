import Foundation

/// One file to convert into one destination.
public struct ConversionRequest: Sendable, Equatable {
    public let source: URL
    public let destination: URL
    public let sourceFormat: FormatDescriptor
    public let targetFormat: FormatDescriptor

    public init(source: URL, destination: URL, sourceFormat: FormatDescriptor, targetFormat: FormatDescriptor) {
        self.source = source
        self.destination = destination
        self.sourceFormat = sourceFormat
        self.targetFormat = targetFormat
    }
}
