#if os(macOS)
import AppKit
import Foundation
import TransfloDomain

/// SVG input: vector-preserving PDF, or rasterization handed to a raster engine for the encoding.
///
/// Small drawings are upscaled so the long edge is at least `minimumLongEdge` pixels.
public struct SVGEngine: ConversionEngine {
    public let id = EngineIDs.svg
    static let minimumLongEdge: CGFloat = 1024
    static let intermediate = FormatDescriptor(
        id: FormatID("png"),
        displayName: "PNG",
        extensions: ["png"],
        family: .image
    )

    private let rasterEngines: [any ConversionEngine]

    /// - Parameter rasterEngines: Engines tried in order to encode the rasterized PNG into the target.
    public init(rasterEngines: [any ConversionEngine]) {
        self.rasterEngines = rasterEngines
    }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        guard source.id.rawValue == "svg" else { return false }
        return target.id.rawValue == "pdf" || target.id == Self.intermediate.id || encoder(for: target) != nil
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard FileManager.default.fileExists(atPath: request.source.path) else { throw .sourceMissing }
        let wantsPDF = request.targetFormat.id.rawValue == "pdf"
        let raster = try await BlockingWork.run { () throws(JobError) -> CGImage? in
            guard let drawing = NSImage(contentsOf: request.source), drawing.size.width > 0, drawing.size.height > 0
            else {
                throw .failed
            }
            if wantsPDF {
                try writeVectorPDF(drawing, to: request.destination)
                return nil
            }
            return try rasterize(drawing)
        }
        if let raster {
            progress(0.4)
            if request.targetFormat.id == Self.intermediate.id {
                try await BlockingWork.run { () throws(JobError) in
                    try PNGWriter.write(raster, to: request.destination)
                }
            } else {
                try await encode(raster, request: request, progress: progress)
            }
        }
        progress(1)
        return [request.destination]
    }

    private func encoder(for target: FormatDescriptor) -> (any ConversionEngine)? {
        rasterEngines.first { $0.canConvert(from: Self.intermediate, to: target) }
    }

    private func encode(
        _ raster: CGImage,
        request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        guard let encoder = encoder(for: request.targetFormat) else { throw .unsupported }
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-svg-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try await BlockingWork.run { () throws(JobError) in try PNGWriter.write(raster, to: temporary) }
        let inner = ConversionRequest(
            source: temporary,
            destination: request.destination,
            sourceFormat: Self.intermediate,
            targetFormat: request.targetFormat
        )
        _ = try await encoder.convert(inner) { progress(0.4 + $0 * 0.6) }
    }

    private func rasterize(_ drawing: NSImage) throws(JobError) -> CGImage {
        let scale = max(1, Self.minimumLongEdge / max(drawing.size.width, drawing.size.height))
        let size = CGSize(width: drawing.size.width * scale, height: drawing.size.height * scale)
        guard RasterLimits.allows(size) else { throw .unsupported }
        var rect = CGRect(origin: .zero, size: size)
        guard let image = drawing.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { throw .failed }
        return image
    }

    private func writeVectorPDF(_ drawing: NSImage, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in try writeVectorPDFStaged(drawing, to: staged) }
    }

    private func writeVectorPDFStaged(_ drawing: NSImage, to url: URL) throws(JobError) {
        var mediaBox = CGRect(origin: .zero, size: drawing.size)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw .destinationUnavailable }
        context.beginPDFPage(nil)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        drawing.draw(in: mediaBox)
        NSGraphicsContext.current = previous
        context.endPDFPage()
        context.closePDF()
    }
}
#endif
