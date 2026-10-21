#if os(macOS)
import PDFKit
import TransfloDomain

/// Rebuilds table rows from a PDF's text layout. PDFKit's line selections give the rows; within
/// a line, a cell boundary is a horizontal gap much wider than the surrounding letters.
/// One sheet per page.
enum PDFTableExtractor {
    struct Glyph {
        let character: String
        let frame: CGRect
    }

    static func workbook(from document: PDFDocument) -> Workbook {
        let sheets = (0..<document.pageCount).compactMap { index -> SpreadsheetSheet? in
            guard let page = document.page(at: index) else { return nil }
            let rows = lines(on: page).map { cells(of: $0).map(SpreadsheetCell.inferred) }.filter { !$0.isEmpty }
            return rows.isEmpty ? nil : SpreadsheetSheet(name: "Page \(index + 1)", rows: rows)
        }
        return Workbook(sheets: sheets.isEmpty ? [SpreadsheetSheet(name: "Page 1", rows: [])] : sheets)
    }

    /// Each line's visible characters with their bounds.
    ///
    /// `characterBounds(at:)` indexes the page text *without* the newlines PDFKit inserts into
    /// `page.string`, while selection ranges include them, so each line's range is shifted back
    /// by the number of newlines before it.
    static func lines(on page: PDFPage) -> [[Glyph]] {
        guard let selection = page.selection(for: page.bounds(for: .mediaBox)) else { return [] }
        let pageText = (page.string ?? "") as NSString
        return selection.selectionsByLine().map { line in
            let range = line.range(at: 0, on: page)
            guard range.location != NSNotFound, NSMaxRange(range) <= pageText.length else { return [] }
            let shift = newlineCount(in: pageText, before: range.location)
            var glyphs: [Glyph] = []
            var offset = range.location
            while offset < NSMaxRange(range) {
                let composed = pageText.rangeOfComposedCharacterSequence(at: offset)
                defer { offset = NSMaxRange(composed) }
                let character = pageText.substring(with: composed)
                guard !character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let frame = page.characterBounds(at: composed.location - shift)
                guard frame.width > 0, frame.height > 0 else { continue }
                glyphs.append(Glyph(character: character, frame: frame))
            }
            return glyphs.sorted { $0.frame.minX < $1.frame.minX }
        }
    }

    private static func newlineCount(in text: NSString, before location: Int) -> Int {
        var count = 0
        for index in 0..<location {
            if let scalar = Unicode.Scalar(text.character(at: index)), CharacterSet.newlines.contains(scalar) {
                count += 1
            }
        }
        return count
    }

    private static func cells(of line: [Glyph]) -> [String] {
        let widths = line.map(\.frame.width).sorted()
        let typical = widths.isEmpty ? 5 : widths[widths.count / 2]
        let cellGap = max(typical * 2.2, 8)
        let wordGap = typical * 0.25
        var cells: [String] = []
        var current = ""
        var previous: Glyph?
        for glyph in line {
            if let previous {
                let gap = glyph.frame.minX - previous.frame.maxX
                if gap > cellGap {
                    cells.append(current)
                    current = ""
                } else if gap > wordGap {
                    current.append(" ")
                }
            }
            current.append(glyph.character)
            previous = glyph
        }
        if !current.isEmpty { cells.append(current) }
        return cells
    }
}
#endif
