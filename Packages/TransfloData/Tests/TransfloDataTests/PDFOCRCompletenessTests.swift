import AppKit
import CoreText
import Foundation
import PDFKit
import Testing
import TransfloData

@Suite("PDF OCR completeness", .serialized)
struct PDFOCRCompletenessTests {
    @Test("mixed PDFs recognize scanned pages as well as selectable pages")
    func mixedPages() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mixed-ocr-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var bounds = CGRect(x: 0, y: 0, width: 400, height: 100)
        let context = try #require(CGContext(url as CFURL, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 20, y: 40)
        CTLineDraw(line("SELECTABLE FIRST PAGE"), context)
        context.endPDFPage()
        context.beginPDFPage(nil)
        context.draw(try image("SCANNED SECOND PAGE"), in: bounds)
        context.endPDFPage()
        context.closePDF()
        let text = try await VisionImageUnderstanding().text(in: url)
        #expect(text.contains("SELECTABLE FIRST PAGE"))
        #expect(text.contains("SCANNED SECOND PAGE"))
        let first = try #require(text.range(of: "FIRST"))
        let second = try #require(text.range(of: "SECOND"))
        #expect(first.lowerBound < second.lowerBound)
    }

    @Test("OCR processes text on scanned pages beyond page twenty")
    func pageTwentyOne() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("long-ocr-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var bounds = CGRect(x: 0, y: 0, width: 400, height: 100)
        let context = try #require(CGContext(url as CFURL, mediaBox: &bounds, nil))
        for index in 0..<21 {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            if index == 20 { context.draw(try image("PAGE TWENTY ONE"), in: bounds) }
            context.endPDFPage()
        }
        context.closePDF()
        #expect(try await VisionImageUnderstanding().text(in: url).contains("PAGE TWENTY ONE"))
    }

    private func line(_ text: String) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor.black]))
    }

    private func image(_ text: String) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 400, height: 100, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 100))
        context.textPosition = CGPoint(x: 10, y: 40)
        CTLineDraw(line(text), context)
        return try #require(context.makeImage())
    }
}
