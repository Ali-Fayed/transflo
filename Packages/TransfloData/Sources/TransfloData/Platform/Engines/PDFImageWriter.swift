import CoreGraphics
import Foundation
import TransfloDomain

/// Writes a single-page PDF whose page is exactly the image.
enum PDFImageWriter {
    static func write(_ image: CGImage, pointSize: CGSize, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            try writeStaged(image, pointSize: pointSize, to: staged)
        }
    }

    static func writeStaged(_ image: CGImage, pointSize: CGSize, to url: URL) throws(JobError) {
        var mediaBox = CGRect(origin: .zero, size: pointSize)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .destinationUnavailable }
        context.beginPDFPage(nil)
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
    }
}
