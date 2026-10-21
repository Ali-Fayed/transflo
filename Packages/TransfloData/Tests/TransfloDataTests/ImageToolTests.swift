import CoreImage
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

/// Records copied text.
final class SpyCopier: TextCopying, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var stored: [String] = []

    var copied: [String] { lock.withLock { stored } }

    func copy(_ text: String) {
        lock.withLock { stored.append(text) }
    }
}

@Suite("Image tools", .enabled(if: MediaFixtures.hasFFmpeg))
struct ImageToolTests {
    private let copier = SpyCopier()
    private let catalog = MatrixConversionTests.catalog

    private var engine: ImageToolEngine {
        let naming = ToolOutputNaming(
            naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()), suffixes: StubToolSuffixes()
        )
        return ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: naming, copier: copier)
    }

    private func item(_ url: URL) -> ToolItem {
        ToolItem(url: url, format: catalog.format(forFileExtension: url.pathExtension))
    }

    private func run(_ tool: ToolKind, _ urls: [URL], settings: ToolSettings? = nil) async throws -> [URL] {
        let request = ToolRequest(tool: tool, settings: settings ?? .defaults(for: tool), items: urls.map(item))
        return try await engine.run(request) { _ in }
    }

    private func properties(_ url: URL) throws -> [CFString: Any] {
        try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
    }

    private func writeQR(_ message: String, to url: URL) throws {
        let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data(message.utf8), forKey: "inputMessage")
        let code = try #require(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let padded = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -48, dy: -48)))
        let image = try #require(CIContext().createCGImage(padded, from: padded.extent))
        try PNGWriter.write(image, to: url)
    }

    @Test("compress writes a readable, named, smaller file in the same format",
          arguments: ["jpg", "png", "heic", "tiff", "webp"])
    func compress(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try compressible(format, in: folder.url)
        let outputs = try await run(.compress, [source])
        #expect(outputs.map(\.lastPathComponent) == ["source (compress).\(format)"])
        #expect(try properties(outputs[0])[kCGImagePropertyPixelWidth] as? Int == 512)
        #expect(try bytes(outputs[0]) < (try bytes(source)))
    }

    @Test("compressed PNGs are palette images")
    func pngPalette() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let outputs = try await run(.compress, [try compressible("png", in: folder.url)])
        // IHDR color type (byte 25) 3 = indexed palette. ImageIO does not report this property.
        let header = try Data(contentsOf: outputs[0]).prefix(26)
        #expect(header.count == 26 && header[25] == 3)
    }

    @Test("a file no preset can shrink is reported as already small, and nothing is written")
    func alreadySmall() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("png", into: folder.url)
        await #expect(throws: JobError.nothingFound) { try await run(.compress, [source]) }
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.url.path)
        #expect(left == [source.lastPathComponent])
    }

    /// A 512 × 384 photo-like image (gradients and grain) saved at full quality, so every preset can shrink it.
    private func compressible(_ format: String, in folder: URL) throws -> URL {
        let width = 512, height = 384
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: 0, space: space,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        var generator = SystemRandomNumberGenerator()
        for y in 0..<height {
            for x in stride(from: 0, to: width, by: 2) {
                let grain = Double.random(in: -0.06...0.06, using: &generator)
                context.setFillColor(red: Double(x) / Double(width) + grain, green: Double(y) / Double(height) + grain,
                                     blue: 0.5 + grain, alpha: 1)
                context.fill(CGRect(x: x, y: y, width: 2, height: 1))
            }
        }
        let url = folder.appendingPathComponent("source.\(format)")
        let image = try #require(context.makeImage())
        if format == "tiff" {
            // Uncompressed, as cameras and scanners often save it; Compress then applies LZW.
            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.tiff" as CFString,
                                                                           1, nil))
            let options = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 1]] as CFDictionary
            CGImageDestinationAddImage(destination, image, options)
            #expect(CGImageDestinationFinalize(destination))
        } else {
            try ImageFileWriter(ffmpeg: MediaFixtures.ffmpeg).write(image, format: format, quality: 1, to: url)
        }
        return url
    }

    private func bytes(_ url: URL) throws -> Int {
        try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
    }

    @Test("strong compression caps the long edge")
    func strongDownscale() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let big = folder.url.appendingPathComponent("big.jpg")
        let seed = try #require(MediaFixtures.makeTestImage())
        let image = try #require(ImageScaling.draw(seed, width: 4000, height: 3000) {
            $0.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.4, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        })
        try ImageFileWriter(ffmpeg: nil).write(image, format: "jpg", to: big)
        let outputs = try await run(.compress, [big], settings: .compress(.strong))
        #expect(try properties(outputs[0])[kCGImagePropertyPixelWidth] as? Int == 2560)
    }

    @Test("rotate turns clockwise and flips")
    func rotate() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("png", into: folder.url)
        let turned = try await run(.rotate, [source])
        #expect(try properties(turned[0])[kCGImagePropertyPixelWidth] as? Int == 48)
        // The fixture's transparent left half ends up on top after a clockwise turn.
        let image = try #require(CGImageSourceCreateWithURL(turned[0] as CFURL, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, nil)
        })
        let top = try alpha(of: image, x: 24, y: 2)
        let bottom = try alpha(of: image, x: 24, y: 61)
        #expect(top < 10 && bottom > 245)
        let mirror = ToolSettings.rotate(quarterTurns: 0, flipHorizontal: true, flipVertical: true)
        let flipped = try await run(.rotate, [source], settings: mirror)
        #expect(try properties(flipped[0])[kCGImagePropertyPixelWidth] as? Int == 64)
    }

    private func alpha(of image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
        return bytes[(y * image.width + x) * 4 + 3]
    }

    @Test("remove metadata strips GPS and EXIF")
    func stripsMetadata() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("tagged.jpg")
        let jpeg = "public.jpeg" as CFString
        let destination = try #require(CGImageDestinationCreateWithURL(source as CFURL, jpeg, 1, nil))
        let picture = try #require(MediaFixtures.makeTestImage())
        CGImageDestinationAddImage(destination, picture, [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30.04, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret"]
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        #expect(try properties(source)[kCGImagePropertyGPSDictionary] != nil)
        let outputs = try await run(.removeMetadata, [source])
        let stripped = try properties(outputs[0])
        #expect(stripped[kCGImagePropertyGPSDictionary] == nil)
        #expect((stripped[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifUserComment] == nil)
    }

    @Test("QR codes are read from images and PDFs and copied")
    func readsCodes() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let codeImage = folder.url.appendingPathComponent("code.png")
        try writeQR("https://transflo.app/hello", to: codeImage)
        #expect(try await run(.readCode, [codeImage]).isEmpty)
        let pdfs = try await run(.imagesToPDF, [codeImage, codeImage])
        #expect(PDFDocument(url: pdfs[0])?.pageCount == 2)
        _ = try await run(.readCode, [pdfs[0]])
        #expect(copier.copied == ["https://transflo.app/hello", "https://transflo.app/hello"])
    }

    @Test("no code or no subject reports nothingFound and writes nothing")
    func nothingFound() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let blank = folder.url.appendingPathComponent("blank.png")
        let seed = try #require(MediaFixtures.makeTestImage())
        let image = try #require(ImageScaling.draw(seed, width: 200, height: 200) {
            $0.setFillColor(CGColor(gray: 1, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        })
        try PNGWriter.write(image, to: blank)
        await #expect(throws: JobError.nothingFound) { _ = try await run(.readCode, [blank]) }
        await #expect(throws: JobError.nothingFound) { _ = try await run(.removeBackground, [blank]) }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: folder.url.path)
        #expect(leftovers == ["blank.png"])
    }

    @Test("capabilities follow formats and file counts")
    func capabilities() {
        let png = catalog.format(FormatID("png"))
        let gif = catalog.format(FormatID("gif"))
        let pdf = catalog.format(FormatID("pdf"))
        let svg = catalog.format(FormatID("svg"))
        #expect(engine.canRun(.compress, on: [png]))
        #expect(!engine.canRun(.compress, on: [gif]))
        #expect(engine.canRun(.rotate, on: [gif]))
        #expect(!engine.canRun(.rotate, on: [svg]))
        #expect(engine.canRun(.readCode, on: [pdf, png]))
        #expect(!engine.canRun(.imagesToPDF, on: [png]))
        #expect(engine.canRun(.imagesToPDF, on: [png, png]))
        #expect(!engine.canRun(.trim, on: [png]))
        #expect(!ImageToolEngine(ffmpeg: nil, naming: ToolOutputNaming(
            naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()), suffixes: StubToolSuffixes()
        ), copier: copier).canRun(.rotate, on: [catalog.format(FormatID("webp"))]))
    }
}

@Suite("Tool catalog file")
struct ToolCatalogFileTests {
    @Test("tools.json lists every tool with valid rules")
    func bundled() throws {
        let catalog = try BundledToolCatalogLoader().load()
        #expect(catalog.tools.map(\.kind) == ToolKind.allCases)
        #expect(catalog.descriptor(for: .merge)?.requiresMultipleFiles == true)
        #expect(catalog.descriptor(for: .rename)?.appliesToAnyFile == true)
        #expect(catalog.descriptor(for: .extractPages)?.formats == [FormatID("pdf")])
    }

    @Test("invalid tool files are rejected", arguments: [
        #"{"version":2,"tools":[]}"#,
        #"{"version":1,"tools":[{"kind":"teleport","families":["image"],"formats":[]}]}"#,
        #"{"version":1,"tools":[{"kind":"crop","families":["smell"],"formats":[]}]}"#,
        #"{"version":1,"tools":[{"kind":"crop","families":[],"formats":[]}]}"#,
        #"{"version":1,"tools":[{"kind":"crop","families":["image"],"formats":[]},"#
            + #"{"kind":"crop","families":["image"],"formats":[]}]}"#,
        "nope"
    ])
    func rejects(json: String) throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tools-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect { try BundledToolCatalogLoader(url: file).load() } throws: { error in
            if case .invalid = error as? CatalogError { return true }
            return false
        }
    }
}
