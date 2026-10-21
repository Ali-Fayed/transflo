import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Icons and GIF compression")
struct IconAndGIFTests {
    private let catalog = MatrixConversionTests.catalog
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("icons-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func format(_ id: String) throws -> FormatDescriptor {
        try #require(catalog.format(forFileExtension: id))
    }

    private func convert(_ source: URL, to target: String) async throws -> URL {
        let destination = folder.appendingPathComponent("out.\(target)")
        let request = ConversionRequest(source: source, destination: destination,
                                        sourceFormat: try format(source.pathExtension),
                                        targetFormat: try format(target))
        _ = try await ImageIOEngine().convert(request) { _ in }
        return destination
    }

    private func widths(_ url: URL) throws -> [Int] {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return (0..<CGImageSourceGetCount(source)).compactMap {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, $0, nil) as? [CFString: Any]
            return properties?[kCGImagePropertyPixelWidth] as? Int
        }
    }

    private func png() throws -> URL {
        let url = folder.appendingPathComponent("logo.png")
        try MediaFixtures.writeImage("png", to: url)
        return url
    }

    // MARK: Icons

    @Test func icoHoldsEverySizeUpTo256() async throws {
        let output = try await convert(try png(), to: "ico")
        #expect(try widths(output).max() == 256)
        #expect(try widths(output).count == IconFileWriter.sizes["ico"]?.count)
    }

    @Test func icnsHoldsRetinaSizes() async throws {
        let output = try await convert(try png(), to: "icns")
        #expect(try widths(output).contains(512))
        #expect(try widths(output).contains(16))
    }

    @Test func iconsBackToPNGUseTheLargestSize() async throws {
        let icon = try await convert(try png(), to: "icns")
        let back = try await convert(icon, to: "png")
        #expect(try widths(back) == [512])
    }

    @Test func nonSquareImagesAreCenteredOnATransparentSquare() throws {
        let image = try #require(MediaFixtures.makeTestImage())
        let square = try IconFileWriter.square(image, size: 32)
        #expect(square.width == 32 && square.height == 32)
        #expect(MetalFXUpscaler.hasAlpha(square))
    }

    @Test func unknownIconFormatIsUnsupported() throws {
        let image = try #require(MediaFixtures.makeTestImage())
        #expect(throws: JobError.unsupported) {
            try IconFileWriter.write(image, format: "png", type: "public.png", to: folder.appendingPathComponent("x"))
        }
    }

    @Test func iconsAreConvertibleFromRasterImagesOnly() throws {
        let engine = ImageIOEngine()
        #expect(engine.canConvert(from: try format("heic"), to: try format("icns")))
        #expect(engine.canConvert(from: try format("ico"), to: try format("png")))
        #expect(!engine.canConvert(from: try format("mp4"), to: try format("ico")))
    }

    // MARK: GIF compression

    private func gifEngine(ffmpeg: URL? = MediaFixtures.ffmpeg) -> GIFCompressionEngine {
        let naming = ToolOutputNaming(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
                                      suffixes: StubToolSuffixes())
        return GIFCompressionEngine(ffmpeg: ffmpeg, naming: naming)
    }

    private func compress(_ url: URL, _ settings: ToolSettings) async throws -> [URL] {
        let item = ToolItem(url: url, format: catalog.format(forFileExtension: url.pathExtension))
        return try await gifEngine().run(ToolRequest(tool: .compress, settings: settings, items: [item])) { _ in }
    }

    @Test func gifEngineOnlyCompressesGIFs() throws {
        #expect(gifEngine(ffmpeg: URL(fileURLWithPath: "/usr/bin/true")).canRun(.compress, on: [try format("gif")]))
        #expect(!gifEngine(ffmpeg: URL(fileURLWithPath: "/usr/bin/true")).canRun(.compress, on: [try format("png")]))
        #expect(!gifEngine(ffmpeg: URL(fileURLWithPath: "/usr/bin/true")).canRun(.resize, on: [try format("gif")]))
        #expect(!gifEngine(ffmpeg: nil).canRun(.compress, on: [try format("gif")]))
    }

    @Test func gifArgumentsScaleAndReduceColorsPerStep() {
        let input = URL(fileURLWithPath: "/tmp/a.gif")
        let light = GIFCompressionEngine.arguments(input: input, step: GIFCompressionEngine.ladder[0],
                                                   maximumLongEdge: nil)
        let strong = GIFCompressionEngine.arguments(input: input, step: GIFCompressionEngine.ladder[2],
                                                    maximumLongEdge: 320)
        #expect(light.joined(separator: " ").contains("max_colors=256") && !light.joined().contains("lanczos"))
        #expect(strong.joined(separator: " ").contains("max_colors=64"))
        #expect(strong.joined(separator: " ").contains("iw*0.75") && strong.joined().contains("min(iw,320)"))
    }

    @Test func gifSettingsMustBeACompressGoal() {
        #expect(throws: JobError.unsupported) { try GIFCompressionEngine.goal(.none) }
        #expect(throws: JobError.unsupported) {
            try GIFCompressionEngine.goal(.compressImage(goal: .medium, maximumLongEdge: 0))
        }
        #expect(GIFCompressionEngine.index(for: .strong) == 2)
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func compressingAGIFMakesItSmaller() async throws {
        let source = try await MediaFixtures.make("gif", in: folder)
        let output = try #require(try await compress(source, .compress(.strong)).first)
        let before = try #require(try source.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let after = try #require(try output.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(after < before)
        #expect(output.lastPathComponent == "source (compress).gif")
    }

    @Test(.enabled(if: MediaFixtures.hasFFmpeg))
    func anUnreachableSizeIsReported() async throws {
        let source = try await MediaFixtures.make("gif", in: folder)
        await #expect(throws: JobError.targetUnreachable) {
            try await compress(source, .compress(.targetBytes(10)))
        }
    }

    @Test func aMissingGIFIsReported() async {
        await #expect(throws: JobError.sourceMissing) {
            try await compress(folder.appendingPathComponent("gone.gif"), .compress(.medium))
        }
    }
}
