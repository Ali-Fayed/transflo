#if os(macOS)
import Foundation
import TransfloDomain

/// Reads Finder text clippings (`.textClipping`): a property list whose `UTI-Data` holds the
/// dragged text as RTF and/or plain text.
enum TextClippingReader {
    static func read(_ url: URL) throws(JobError) -> NSAttributedString {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let payload = plist["UTI-Data"] as? [String: Any]
        else { throw .failed }
        if let rtf = payload["public.rtf"] as? Data,
           let text = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                              documentAttributes: nil) {
            return text
        }
        if let text = plainText(payload["public.utf8-plain-text"], encoding: .utf8)
            ?? plainText(payload["public.utf16-plain-text"], encoding: .utf16) {
            return NSAttributedString(string: text, attributes: [.font: AttributedDocumentRenderer.bodyFont])
        }
        throw .failed
    }

    private static func plainText(_ value: Any?, encoding: String.Encoding) -> String? {
        (value as? String) ?? (value as? Data).flatMap { String(data: $0, encoding: encoding) }
    }
}
#endif
