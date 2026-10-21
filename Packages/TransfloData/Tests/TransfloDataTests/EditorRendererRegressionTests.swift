import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Editor renderers")
struct EditorRendererRegressionTests {
    @Test("collage preview and export preserve source order and declared output dimensions")
    func collage() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        var urls: [URL] = []
        for (name, color) in [("red", CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),
                              ("blue", CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))] {
            let context = try #require(CGContext(data: nil, width: 30, height: 20, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
            let url = folder.url.appendingPathComponent(name + ".png")
            try PNGWriter.write(#require(context.makeImage()), to: url)
            urls.append(url)
        }
        let settings = CollageSettings(order: [1, 0], columns: 2, spacing: 0, background: "#FFFFFF",
                                        cellWidth: 30, cellHeight: 20, fill: true)
        let output = try CollageRenderer.render(urls, settings: settings)
        #expect(output.width == 60 && output.height == 20)
        let preview = try CollageRenderer.render(urls, settings: settings, preview: true)
        #expect(preview.width == output.width && preview.height == output.height)
        let context = try #require(CGContext(data: nil, width: 60, height: 20, bitsPerComponent: 8,
            bytesPerRow: 60 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(output, in: CGRect(x: 0, y: 0, width: 60, height: 20))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let left = (10 * 60 + 10) * 4
        let right = (10 * 60 + 45) * 4
        #expect(bytes[left + 2] > 240 && bytes[left] < 15)
        #expect(bytes[right] > 240 && bytes[right + 2] < 15)
    }

    @Test("selective metadata removal clears location without discarding author metadata")
    func selectiveMetadata() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("tagged.jpg")
        let image = try #require(MediaFixtures.makeTestImage())
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 30, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "Author"]
        ]
        try ImageFileWriter(ffmpeg: nil).write(image, format: "jpg", properties: properties, to: source)
        let format = MatrixConversionTests.catalog.format(forFileExtension: "jpg")
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        let outputs = try await engine.run(ToolRequest(tool: .removeMetadata, settings: .removeMetadata([.location]),
            items: [ToolItem(url: source, format: format)])) { _ in }
        let output = try #require(outputs.first)
        let decoded = try ImageDecoding.decodeUpright(output)
        #expect(decoded.properties[kCGImagePropertyGPSDictionary] == nil)
        let tiff = decoded.properties[kCGImagePropertyTIFFDictionary] as? [String: Any]
        #expect(tiff?[kCGImagePropertyTIFFArtist as String] as? String == "Author")
    }

    @Test("location removal also covers IPTC location fields without deleting the caption")
    func iptcLocation() {
        let properties: [CFString: Any] = [kCGImagePropertyIPTCDictionary: [
            "City": "Private city", "CountryPrimaryLocationName": "Private country", "CaptionAbstract": "Caption"
        ]]
        let entries = MetadataFiltering.entries(properties)
        #expect(entries.filter { $0.category == .location }.count == 2)
        let filtered = MetadataFiltering.image(properties, removing: [.location])
        let remaining = filtered[kCGImagePropertyIPTCDictionary] as? [String: String]
        #expect(remaining == ["CaptionAbstract": "Caption"])
    }

    @Test("PDF fit and fill share centering while fitting stays inside the content area")
    func pdfPlacement() {
        let page = CGSize(width: 600, height: 800)
        var layout = AssemblySettings(order: [0, 1], margin: 30)
        let fit = layout.imageFrame(image: CGSize(width: 400, height: 200), page: page)
        #expect(fit.width == 540 && fit.height == 270)
        #expect(fit.midX == 300 && fit.midY == 400)
        layout.fill = true
        let fill = layout.imageFrame(image: CGSize(width: 400, height: 200), page: page)
        #expect(fill.height == 740 && fill.width == 1480)
    }
}
