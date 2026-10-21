import CoreGraphics
import ImageIO
import PDFKit
import TransfloDomain
import UniformTypeIdentifiers

/// Renders PDF pages to JPG or PNG at 300 DPI, on white.
struct PDFPageImageExporter {
    static let dpi: CGFloat = 300

    let naming: NameOutputFileUseCase

    func export(
        _ document: PDFDocument,
        request: ConversionRequest,
        isCancelled: () -> Bool,
        progress: (Double) -> Void
    ) throws(JobError) -> [URL] {
        let fileExtension = request.targetFormat.outputExtension
        let type = fileExtension == "png" ? UTType.png : UTType.jpeg
        if document.pageCount == 1, let page = document.page(at: 0) {
            try write(page, type: type, to: request.destination)
            progress(1)
            return [request.destination]
        }
        let folder = try makeFolder(for: request)
        let base = request.source.deletingPathExtension().lastPathComponent
        do throws(JobError) {
            for index in 0..<document.pageCount {
                if isCancelled() { throw .cancelled }
                guard let page = document.page(at: index) else { continue }
                let file = folder.appendingPathComponent("\(base) \(index + 1)").appendingPathExtension(fileExtension)
                try write(page, type: type, to: file)
                progress(Double(index + 1) / Double(document.pageCount))
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return [folder]
    }

    /// `name (PNG)` beside the source, numbered if taken.
    private func makeFolder(for request: ConversionRequest) throws(JobError) -> URL {
        let base = request.source.deletingPathExtension().lastPathComponent
        let label = request.targetFormat.displayName
        let candidate = request.source.deletingLastPathComponent()
            .appendingPathComponent("\(base) (\(label)).placeholder")
        let folder = try naming.execute(for: candidate, pathExtension: "")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        } catch {
            throw .destinationUnavailable
        }
        return folder
    }

    private func write(_ page: PDFPage, type: UTType, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in try writeStaged(page, type: type, to: staged) }
    }

    private func writeStaged(_ page: PDFPage, type: UTType, to url: URL) throws(JobError) {
        let image = try Self.render(page, dpi: Self.dpi)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw .destinationUnavailable }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: Self.dpi,
            kCGImagePropertyDPIHeight: Self.dpi,
            kCGImageDestinationLossyCompressionQuality: 0.9
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .failed }
    }

    /// Renders `page` in its displayed orientation on white.
    static func render(_ page: PDFPage, dpi: CGFloat) throws(JobError) -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let rotated = page.rotation % 180 != 0
        let points = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        let scale = dpi / 72
        let pixels = CGSize(width: (points.width * scale).rounded(), height: (points.height * scale).rounded())
        guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
              scale.isFinite, scale > 0, RasterLimits.allows(pixels) else { throw .failed }
        let width = Int(pixels.width)
        let height = Int(pixels.height)
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { throw .failed }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { throw .failed }
        return image
    }
}
