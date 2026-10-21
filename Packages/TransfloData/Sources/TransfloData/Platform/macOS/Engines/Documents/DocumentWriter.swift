#if os(macOS)
import AppKit
import NaturalLanguage
import TransfloDomain

/// Writes a loaded document in any supported text output format.
enum DocumentWriter {
    static func write(_ document: LoadedDocument, format: String, title: String, to url: URL) throws(JobError) {
        let text = document.text
        let range = NSRange(location: 0, length: text.length)
        switch format {
        case "txt":
            try TextFileReader.write(text.string, to: url)
        case "md":
            try TextFileReader.write(MarkdownWriter.markdown(for: document.structure), to: url)
        case "docx":
            let attributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.officeOpenXML
            ]
            try write(text, range: range, attributes: attributes, to: url)
        case "html":
            try write(text, range: range, attributes: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
                .title: title
            ], to: url)
        case "epub":
            try EPUBWriter.write(document.structure, title: title, language: language(of: text.string), to: url)
        case "pdf":
            try PDFTextPaginator.write(text, to: url)
        default:
            throw .unsupported
        }
    }

    private static func write(
        _ text: NSAttributedString,
        range: NSRange,
        attributes: [NSAttributedString.DocumentAttributeKey: Any],
        to url: URL
    ) throws(JobError) {
        guard let data = try? text.data(from: range, documentAttributes: attributes) else { throw .failed }
        try OutputFile.write(to: url) { staged throws(JobError) in
            do { try data.write(to: staged) } catch { throw .failed }
        }
    }

    /// BCP-47 code of the text's dominant language, for EPUB metadata.
    static func language(of text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(2000)))
        return recognizer.dominantLanguage?.rawValue ?? "und"
    }
}
#endif
