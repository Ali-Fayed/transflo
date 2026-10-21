#if os(macOS)
import CoreText
import Foundation
import TransfloDomain

/// Lays out an attributed string across PDF pages with CoreText (thread-safe; no print system).
enum PDFTextPaginator {
    static let letter = CGSize(width: 612, height: 792)
    static let isoA4 = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 54
    /// Regions that use US Letter paper.
    static let letterRegions: Set<String> = ["US", "CA", "MX", "PH", "CL", "CO", "VE", "GT", "PR"]

    static func pageSize(forRegion region: String?) -> CGSize {
        region.map(letterRegions.contains) == true ? letter : isoA4
    }

    static func write(
        _ text: NSAttributedString,
        to url: URL,
        pageSize: CGSize = pageSize(forRegion: Locale.current.region?.identifier)
    ) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            try writeStaged(text, to: staged, pageSize: pageSize)
        }
    }

    private static func writeStaged(
        _ text: NSAttributedString,
        to url: URL,
        pageSize: CGSize = pageSize(forRegion: Locale.current.region?.identifier)
    ) throws(JobError) {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .destinationUnavailable }
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: mediaBox.insetBy(dx: margin, dy: margin), transform: nil)
        var start = 0
        repeat {
            if BlockingWork.isCancelled { context.closePDF(); throw .cancelled }
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame).length
            guard visible > 0 else { break }
            start += visible
        } while start < text.length
        context.closePDF()
    }
}
#endif
