#if os(macOS)
import CoreText
import Foundation
import TransfloDomain

/// Draws sheets as ruled tables across PDF pages: header row repeated on every page,
/// numbers right-aligned, long cells truncated, wide sheets in landscape and scaled to fit.
enum SpreadsheetPDFRenderer {
    static var font: PlatformFont { PlatformFont.systemFont(ofSize: 9) }
    static var titleFont: PlatformFont { PlatformFont.boldSystemFont(ofSize: 11) }
    static let cellPadding: CGFloat = 4
    static let columnWidthRange: ClosedRange<CGFloat> = 24...180
    static let minimumScale: CGFloat = 0.5

    static func write(_ workbook: Workbook, to url: URL, pageSize: CGSize) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            try writeStaged(workbook, to: staged, pageSize: pageSize)
        }
    }

    static func writeStaged(_ workbook: Workbook, to url: URL, pageSize: CGSize) throws(JobError) {
        let sheets = workbook.sheets.filter { !$0.rows.isEmpty }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .destinationUnavailable }
        if sheets.isEmpty {
            context.beginPDFPage(nil)
            context.endPDFPage()
        }
        for sheet in sheets {
            let widths = columnWidths(sheet)
            let capacity = (max(pageSize.width, pageSize.height) - PDFTextPaginator.margin * 2) / minimumScale
            var start = 0
            while start < widths.count {
                var end = start
                var width: CGFloat = 0
                while end < widths.count, width + widths[end] <= capacity {
                    width += widths[end]
                    end += 1
                }
                end = max(start + 1, end)
                let part = SpreadsheetSheet(name: sheet.name, rows: sheet.rows.map {
                    Array($0.dropFirst(start).prefix(end - start))
                })
                draw(part, in: context, portrait: pageSize)
                start = end
            }
        }
        context.closePDF()
    }

    private static func draw(_ sheet: SpreadsheetSheet, in context: CGContext, portrait: CGSize) {
        let widths = columnWidths(sheet)
        let tableWidth = widths.reduce(0, +)
        let margin = PDFTextPaginator.margin
        let landscape = tableWidth > portrait.width - margin * 2
        let page = landscape ? CGSize(width: portrait.height, height: portrait.width) : portrait
        let scale = max(minimumScale, min(1, (page.width - margin * 2) / max(tableWidth, 1)))
        let rowHeight = (font.ascender - font.descender + font.leading) + cellPadding * 2
        let usableHeight = (page.height - margin * 2) / scale - rowHeight * 2
        let rowsPerPage = max(1, Int(usableHeight / rowHeight))
        let header = sheet.rows.first ?? []
        var body = Array(sheet.rows.dropFirst())
        repeat {
            let chunk = Array(body.prefix(rowsPerPage))
            body.removeFirst(chunk.count)
            var box = CGRect(origin: .zero, size: page)
            context.beginPDFPage([kCGPDFContextMediaBox as String: Data(bytes: &box, count: MemoryLayout<CGRect>.size)]
                as CFDictionary)
            context.saveGState()
            context.translateBy(x: margin, y: page.height - margin)
            context.scaleBy(x: scale, y: scale)
            drawText(sheet.name, font: titleFont, in: CGRect(x: 0, y: -rowHeight, width: tableWidth, height: rowHeight),
                     alignRight: false, context: context)
            for (index, row) in ([header] + chunk).enumerated() {
                let band = CGRect(x: 0, y: -rowHeight * CGFloat(index + 2), width: tableWidth, height: rowHeight)
                drawRow(row, widths: widths, band: band, bold: index == 0, context: context)
            }
            context.restoreGState()
            context.endPDFPage()
        } while !body.isEmpty
    }

    private static func columnWidths(_ sheet: SpreadsheetSheet) -> [CGFloat] {
        (0..<sheet.columnCount).map { column in
            let widest = sheet.rows.prefix(500).map { row -> CGFloat in
                guard column < row.count else { return 0 }
                return textWidth(row[column].text)
            }.max() ?? 0
            return min(max(widest + cellPadding * 2, columnWidthRange.lowerBound), columnWidthRange.upperBound)
        }
    }

    /// Draws one row inside `band` (its y and height; x and width come from `widths`).
    private static func drawRow(
        _ row: [SpreadsheetCell], widths: [CGFloat], band: CGRect, bold: Bool, context: CGContext
    ) {
        var x: CGFloat = 0
        context.setStrokeColor(CGColor(gray: 0.75, alpha: 1))
        context.setLineWidth(0.5)
        for (column, width) in widths.enumerated() {
            let frame = CGRect(x: x, y: band.minY, width: width, height: band.height)
            context.stroke(frame)
            if column < row.count, row[column].kind != .empty {
                let cellFont = bold ? PlatformGraphics.bold(font) : font
                drawText(row[column].text, font: cellFont, in: frame, alignRight: row[column].kind == .number,
                         context: context)
            }
            x += width
        }
    }

    private static func drawText(
        _ text: String, font: PlatformFont, in frame: CGRect, alignRight: Bool, context: CGContext
    ) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text.replacingOccurrences(of: "\n", with: " "), attributes: [.font: font]
        ))
        let available = Double(frame.width - cellPadding * 2)
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: [.font: font]))
        let fitted = CTLineCreateTruncatedLine(line, available, .end, ellipsis) ?? line
        let width = CGFloat(CTLineGetTypographicBounds(fitted, nil, nil, nil))
        let x = alignRight ? frame.maxX - cellPadding - width : frame.minX + cellPadding
        context.textPosition = CGPoint(x: x, y: frame.minY + cellPadding - font.descender)
        CTLineDraw(fitted, context)
    }

    private static func textWidth(_ text: String) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}
#endif
