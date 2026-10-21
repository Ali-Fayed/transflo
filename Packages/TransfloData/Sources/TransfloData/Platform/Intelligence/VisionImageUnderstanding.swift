import CoreGraphics
import Foundation
import PDFKit
import TransfloDomain
import Vision

/// What's in an image, on device: Vision's scene labels and text recognition. A PDF's text comes from
/// its text layer, falling back to recognizing its first pages when it is a scan.
public struct VisionImageUnderstanding: ImageUnderstanding {
    static let minimumConfidence: Float = 0.3
    static let labelLimit = 8
    /// Long edge images are analyzed at: plenty for labels and readable text, without decoding huge photos.
    static let analysisEdge = 2048
    public init() {}

    public func labels(for url: URL) async throws(JobError) -> [String] {
        guard url.pathExtension.lowercased() != "pdf" else { return [] }
        return try await BlockingWork.runCancellable { _ throws(JobError) -> [String] in
            let image = try ImageDecoding.decodeUpright(url, longEdge: Self.analysisEdge).image
            let request = VNClassifyImageRequest()
            do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { throw .failed }
            return (request.results ?? [])
                .filter { $0.confidence >= Self.minimumConfidence }
                .prefix(Self.labelLimit)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        }
    }

    public func text(in url: URL) async throws(JobError) -> String {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) -> String in
            guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
            if url.pathExtension.lowercased() == "pdf" { return try Self.text(inPDF: url, isCancelled: isCancelled) }
            return try Self.recognizeText(in: ImageDecoding.decodeUpright(url, longEdge: Self.analysisEdge).image)
        }
    }

    private static func text(inPDF url: URL, isCancelled: () -> Bool) throws(JobError) -> String {
        let document = try PDFKitEngine.open(url)
        var pages: [String] = []
        for index in 0..<document.pageCount {
            if isCancelled() { throw .cancelled }
            let page = try RasterLimits.withPool { () throws(JobError) -> String in
                guard let page = document.page(at: index) else { return "" }
                let layer = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !layer.isEmpty { return layer }
                return try recognizeText(in: PDFPageImageExporter.render(page, dpi: 200))
            }
            if !page.isEmpty { pages.append(page) }
        }
        return pages.joined(separator: "\n\n")
    }

    /// Recognized lines, top to bottom.
    static func recognizeText(in image: CGImage) throws(JobError) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { throw .failed }
        if BlockingWork.isCancelled { throw .cancelled }
        return (request.results ?? [])
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
