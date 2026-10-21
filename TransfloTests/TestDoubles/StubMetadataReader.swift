import Foundation
import TransfloDomain

/// Returns fixed metadata for every file.
nonisolated struct StubMetadataReader: ToolMetadataReading {
    let values: [MetadataField: String]

    init(_ values: [MetadataField: String] = [:]) {
        self.values = values
    }

    func metadata(of url: URL, format: FormatDescriptor?) async -> [MetadataField: String] {
        values
    }
}
