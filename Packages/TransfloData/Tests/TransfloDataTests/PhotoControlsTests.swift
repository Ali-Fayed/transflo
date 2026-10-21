import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Photo adjustment and compression controls")
struct PhotoControlsTests {
    struct FilterCase: Sendable, CustomTestStringConvertible {
        let name: String
        let adjustments: ImageAdjustments
        var testDescription: String { name }
    }

    static let cases: [FilterCase] = [
        .init(name: "exposure", adjustments: .init(exposure: 0.7, contrast: 1, saturation: 1)),
        .init(name: "brightness", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, brightness: 0.2)),
        .init(name: "contrast", adjustments: .init(exposure: 0, contrast: 1.4, saturation: 1)),
        .init(name: "saturation", adjustments: .init(exposure: 0, contrast: 1, saturation: 0)),
        .init(name: "highlights", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, highlights: 0.8)),
        .init(name: "shadows", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, shadows: 0.8)),
        .init(name: "warmth", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, temperature: 0.8)),
        .init(name: "tint", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, tint: 0.6)),
        .init(name: "vibrance", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, vibrance: 0.8)),
        .init(name: "sharpness", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, sharpness: 0.8)),
        .init(name: "noise", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, noiseReduction: 0.8)),
        .init(name: "vignette", adjustments: .init(exposure: 0, contrast: 1, saturation: 1, vignette: 0.8))
    ]

    private func image(width: Int = 160, height: Int = 120) throws -> CGImage {
        var bytes: [UInt8] = []
        for index in 0..<(width * height) {
            bytes += [UInt8((index * 13 + 11) % 256), UInt8((index * 17 + 5) % 256),
                      UInt8((index * 23 + 7) % 256), 255]
        }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }

    private func pixels(_ image: CGImage) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: try #require(context.data), count: image.width * image.height * 4)
    }

    @Test("every exposed adjustment changes pixels without changing dimensions", arguments: cases)
    func adjustmentEffect(_ testCase: FilterCase) throws {
        let original = try image()
        let output = try ImageAdjuster.apply(testCase.adjustments, to: original)
        #expect(output.width == original.width && output.height == original.height)
        #expect(try pixels(output) != pixels(original), "\(testCase.name) must affect exported pixels")
    }

    @Test("neutral processing preserves the exact source")
    func neutral() throws {
        let original = try image()
        #expect(try pixels(ImageAdjuster.apply(.neutral, to: original)) == pixels(original))
    }

    @Test("percentage budgets are honored independently for real encoded files")
    func percentageOutput() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let engine = ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier())
        for side in [160, 256] {
            let source = folder.url.appendingPathComponent("photo-\(side).jpg")
            try ImageFileWriter(ffmpeg: nil).write(
                image(width: side, height: side), format: "jpg", quality: 0.95, to: source
            )
            let before = try #require(source.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            let format = MatrixConversionTests.catalog.format(FormatID("jpg"))
            let request = ToolRequest(tool: .compress, settings: .compress(.percentage(50)),
                                      items: [ToolItem(url: source, format: format)])
            let output = try await engine.run(request) { _ in }
            let after = try #require(output[0].resourceValues(forKeys: [.fileSizeKey]).fileSize)
            #expect(after <= before / 2)
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    @Test("explicit compression sizing downsizes and original-size mode overrides the old strong cap")
    func explicitSizing() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("wide.jpg")
        try ImageFileWriter(ffmpeg: nil).write(image(width: 3000, height: 16), format: "jpg", to: source)
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        for edge in [nil, 1280] as [Int?] {
            let request = ToolRequest(tool: .compress, settings: .compressImage(goal: .strong, maximumLongEdge: edge),
                                      items: [ToolItem(url: source,
                                                       format: MatrixConversionTests.catalog.format(FormatID("jpg")))])
            let output = try await engine.run(request) { _ in }
            let decoded = try ImageDecoding.decodeUpright(output[0]).image
            #expect(decoded.width == (edge ?? 3000))
        }
    }
}
