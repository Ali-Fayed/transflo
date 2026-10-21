import Foundation

/// Reads the editable metadata a file carries now, so the editor can show it.
public protocol ToolMetadataReading: Sendable {
    /// Current values; fields the file doesn't have are absent.
    func metadata(of url: URL, format: FormatDescriptor?) async -> [MetadataField: String]
}
