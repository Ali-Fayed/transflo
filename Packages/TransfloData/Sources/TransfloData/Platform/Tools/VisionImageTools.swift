import CoreGraphics
import CoreImage
import PDFKit
import TransfloDomain
import Vision

/// Vision-backed image tools: background removal and barcode reading.
enum VisionImageTools {
    /// The image with everything but its foreground subjects made transparent.
    static func removeBackground(from image: CGImage) throws(JobError) -> CGImage {
        try removingBackground(from: image, settings: BackgroundRemovalSettings()).image
    }

    static func removingBackground(from image: CGImage, settings: BackgroundRemovalSettings)
        throws(JobError) -> (image: CGImage, subjects: [Int]) {
        guard settings.isValid else { throw .unsupported }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: visionImage(image))
        do { try handler.perform([request]) } catch { throw .failed }
        if BlockingWork.isCancelled { throw .cancelled }
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else { throw .nothingFound }
        let selected = settings.subject.map { IndexSet(integer: $0) } ?? observation.allInstances
        guard selected.isSubset(of: observation.allInstances),
              let mask = try? observation.generateScaledMaskForImage(forInstances: selected, from: handler) else {
            throw .incompatibleSelection
        }
        let original = CIImage(cgImage: image)
        var alpha = CIImage(cvPixelBuffer: mask)
        if settings.feather > 0 {
            alpha = alpha.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: settings.feather * Double(min(image.width, image.height))
            ]).cropped(to: original.extent)
        }
        let backdrop: CIImage
        if let hex = settings.background {
            backdrop = CIImage(color: CIColor(cgColor: ImageMarkup.color(hex))).cropped(to: original.extent)
        } else {
            backdrop = CIImage(color: .clear).cropped(to: original.extent)
        }
        let composed = original.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: backdrop, kCIInputMaskImageKey: alpha
        ])
        guard let result = CIContext().createCGImage(composed, from: original.extent) else { throw .failed }
        return (result, Array(observation.allInstances))
    }

    /// Every distinct barcode / QR payload in `images`, in reading order.
    static func codes(in images: [CGImage]) -> [String] {
        var found: [String] = []
        for image in images {
            let request = VNDetectBarcodesRequest()
            #if os(iOS)
            request.revision = VNDetectBarcodesRequestRevision3
            #endif
            try? VNImageRequestHandler(cgImage: visionImage(image)).perform([request])
            var payloads = (request.results ?? [])
                .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                .compactMap(\.payloadStringValue)
            #if os(iOS)
            if payloads.isEmpty {
                let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                          context: CIContext(options: [.useSoftwareRenderer: true]),
                                          options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
                payloads = (detector?.features(in: CIImage(cgImage: image)) ?? [])
                    .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            }
            #endif
            for payload in payloads where !found.contains(payload) {
                found.append(payload)
            }
        }
        return found
    }

    /// iOS Vision accepts BGRA pixel buffers reliably; RGBA decoding can fail on simulator runtimes.
    private static func visionImage(_ image: CGImage) -> CGImage {
        #if os(iOS)
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
        #else
        return image
        #endif
    }

    /// Detects one PDF page at a time, releasing its raster before rendering the next.
    static func codes(inPDF url: URL, isCancelled: () -> Bool) throws(JobError) -> [String] {
        let document = try PDFKitEngine.open(url)
        var found: [String] = []
        for index in 0..<document.pageCount {
            if isCancelled() { throw .cancelled }
            let payloads = try RasterLimits.withPool { () throws(JobError) -> [String] in
                guard let page = document.page(at: index) else { return [] }
                return codes(in: [try PDFPageImageExporter.render(page, dpi: 200)])
            }
            for payload in payloads where !found.contains(payload) { found.append(payload) }
        }
        return found
    }
}
