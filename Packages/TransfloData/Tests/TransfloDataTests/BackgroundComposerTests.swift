import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain

struct BackgroundComposerTests {
    @Test func outputSizesMatchTheSharedLayoutForEveryRatio() throws {
        let source = try image()
        for ratio in BackgroundCanvasRatio.allCases {
            let style = BackgroundStyle(padding: 0.1, ratio: ratio)
            let output = try BackgroundComposer.compose(source, style: style)
            let size = style.canvasDimensions(imageWidth: source.width, imageHeight: source.height)
            #expect(output.width == Int(size.width) && output.height == Int(size.height))
        }
    }

    @Test func roundedCornersRevealTheCanvasAndOutputIsOpaque() throws {
        let output = try BackgroundComposer.compose(try image(),
                                                    style: BackgroundStyle(fill: .solid("#FF0000"),
                                                                           padding: 0.1, corners: 0.2))
        let corner = try pixel(output, x: 5, y: 5)
        #expect(corner[0] > 240 && corner[2] < 15 && corner[3] == 255)
        let center = try pixel(output, x: output.width / 2, y: output.height / 2)
        #expect(center[2] > 240 && center[0] < 15 && center[3] == 255)
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let jpeg = folder.url.appendingPathComponent("result.jpg")
        try ImageFileWriter(ffmpeg: nil).write(output, format: "jpg", to: jpeg)
        let decoded = try ImageDecoding.decodeUpright(jpeg).image
        #expect(try pixel(decoded, x: 0, y: 0)[3] == 255)
    }

    @Test func everyGradientRendersAndTransparentPixelsKeepTheFillUnderShadow() throws {
        let transparent = try BackgroundComposer.compose(try image(transparent: true),
            style: BackgroundStyle(fill: .solid("#FF0000"), padding: 0.2, shadow: 100))
        let inside = try pixel(transparent, x: 20, y: 20)
        #expect(inside[0] > 240 && inside[2] < 15)
        for preset in BackgroundPreset.allCases {
            let output = try BackgroundComposer.compose(try image(),
                                                        style: BackgroundStyle(fill: .gradient(preset),
                                                                               padding: 0.2, shadow: 70))
            #expect(try pixel(output, x: 0, y: 0) != pixel(output, x: output.width - 1, y: output.height - 1))
        }
    }

    @Test func previewUsesTheComposerAndRejectsInvalidDataAndCancellation() async throws {
        let source = try image()
        let bytes = try PNGWriter.data(source)
        let style = BackgroundStyle(padding: 0.1, ratio: .square)
        let renderer = BackgroundPreviewRenderer()
        let data = try await renderer.render(bytes, style: style)
        let decoded = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let rendered = try #require(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
        let direct = try BackgroundComposer.compose(source, style: style)
        #expect(rendered.width == direct.width && rendered.height == direct.height)
        #expect(try pixel(rendered, x: 0, y: 0) == pixel(direct, x: 0, y: 0))
        await #expect(throws: JobError.failed) { try await renderer.render(Data(), style: style) }
        let task = Task { try await renderer.render(bytes, style: style) }
        task.cancel()
        await #expect(throws: JobError.cancelled) { try await task.value }
    }

    private func image(transparent: Bool = false) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: 100, height: 50, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        if transparent {
            context.fill(CGRect(x: 40, y: 20, width: 20, height: 10))
        } else {
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
        }
        return try #require(context.makeImage())
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
                                             bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (y * image.width + x) * 4
        return (0..<4).map { bytes[offset + $0] }
    }
}
