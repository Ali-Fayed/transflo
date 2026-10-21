import Foundation
@testable import TransfloData

/// Structural checks for zipped XML packages.
enum OOXMLTestSupport {
    /// True when `required` parts exist and every `.xml`/`.rels` part is well-formed XML.
    static func partsParse(_ package: URL, required: [String]) throws -> Bool {
        let workspace = try TemporaryDirectory()
        defer { workspace.cleanUp() }
        try ZipArchiver.extract(package, into: workspace.url)
        let parts = FileManager.default.subpaths(atPath: workspace.url.path) ?? []
        guard required.allSatisfy(parts.contains) else { return false }
        return parts.filter { $0.hasSuffix(".xml") || $0.hasSuffix(".rels") }.allSatisfy { part in
            (try? XMLDocument(contentsOf: workspace.url.appendingPathComponent(part), options: [])) != nil
        }
    }
}
