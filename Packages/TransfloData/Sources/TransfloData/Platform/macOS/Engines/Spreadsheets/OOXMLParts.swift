#if os(macOS)
import Foundation
import TransfloDomain

/// Shared Office Open XML (and ODF) packaging pieces.
enum OOXMLParts {
    static let declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
    static let spreadsheetNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    static let relationshipNamespace = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    static let relationshipsOpen = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
    static let defaultContentTypes =
        "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        + "<Default Extension=\"png\" ContentType=\"image/png\"/>"

    static func rootRelationships(target: String) -> String {
        declaration + relationshipsOpen
            + "<Relationship Id=\"rId1\" Type=\"\(relationshipNamespace)/officeDocument\" Target=\"\(target)\"/>"
            + "</Relationships>"
    }

    /// Writes `files` (path → contents) into a temporary folder and zips them to `destination`.
    /// `binaries` adds non-text parts (images); `stored` entries go first, uncompressed.
    static func package(
        _ files: [String: String],
        binaries: [String: Data] = [:],
        stored: [String] = [],
        to destination: URL
    ) throws(JobError) {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        do {
            let all = files.mapValues { Data($0.utf8) }.merging(binaries) { text, _ in text }
            for (path, data) in all {
                let url = workspace.url.appendingPathComponent(path)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try data.write(to: url)
            }
        } catch {
            throw .failed
        }
        let top = Set(files.keys.map { String($0.split(separator: "/").first ?? "") })
            .union(binaries.keys.map { String($0.split(separator: "/").first ?? "") })
            .subtracting(stored)
            .sorted()
        try ZipArchiver.create(destination, from: workspace.url, stored: stored, entries: top)
    }
}
#endif
