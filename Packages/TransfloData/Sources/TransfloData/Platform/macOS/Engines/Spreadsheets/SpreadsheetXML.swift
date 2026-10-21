#if os(macOS)
import Foundation
import TransfloDomain

/// XXE-safe XML loading and namespace-agnostic helpers for spreadsheet packages.
enum SpreadsheetXML {
    static func load(_ url: URL) throws(JobError) -> XMLDocument {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 32 * 1024 * 1024,
              let data = try? Data(contentsOf: url),
              let document = try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        else { throw .failed }
        return document
    }

    static func elements(_ xpath: String, in node: XMLNode) -> [XMLElement] {
        ((try? node.nodes(forXPath: xpath)) ?? []).compactMap { $0 as? XMLElement }
    }

    /// The value of the attribute whose local name is `name`, whatever its prefix.
    static func attribute(_ name: String, of element: XMLElement) -> String? {
        element.attributes?.first { $0.localName == name }?.stringValue
    }

    /// Text of every descendant whose local name is `name`, joined.
    static func text(of element: XMLElement, descendants name: String, separator: String = "") -> String {
        elements(".//*[local-name()='\(name)']", in: element).map { $0.stringValue ?? "" }.joined(separator: separator)
    }

    /// `relative` resolved against `base`, only if it stays inside `root`.
    static func resolve(_ relative: String, against base: URL, root: URL) -> URL? {
        let url = relative.hasPrefix("/")
            ? root.appendingPathComponent(String(relative.dropFirst()))
            : base.appendingPathComponent(relative)
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root.standardizedFileURL.path + "/") ? url.standardizedFileURL : nil
    }
}
#endif
