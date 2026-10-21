import AppKit
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Conversion regressions")
struct ConversionRegressionTests {
    @Test("probe dimensions match the displayed rotation", arguments: [0, 90, -90, 180, 270])
    func displayedDimensions(rotation: Int) throws {
        let json = """
            {"streams":[{"codec_type":"video","width":320,"height":180,
            "side_data_list":[{"rotation":\(rotation)}]}]}
            """
        let info = try FFprobe.parse(Data(json.utf8))
        let swaps = abs(rotation) % 180 == 90
        #expect(info.width == (swaps ? 180 : 320))
        #expect(info.height == (swaps ? 320 : 180))
        let crop = try #require(MediaEditArguments.crop(
            "/clip.mp4", format: "mp4", rect: NormalizedRect(x: 0, y: 0, width: 1, height: 0.5), info: info
        ))
        #expect(crop.arguments.contains(swaps ? "crop=180:160:0:0,scale=trunc(iw/2)*2:trunc(ih/2)*2"
            : "crop=320:90:0:0,scale=trunc(iw/2)*2:trunc(ih/2)*2"))
    }

    @Test("TIFF encoding preserves existing camera and author properties")
    func tiffMetadata() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let context = try #require(CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let output = folder.url.appendingPathComponent("metadata.tiff")
        try ImageFileWriter(ffmpeg: nil).write(image, format: "tiff", properties: [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "Author", kCGImagePropertyTIFFMake: "Camera"]
        ], to: output)
        let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let tiff = try #require(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        #expect(tiff[kCGImagePropertyTIFFArtist] as? String == "Author")
        #expect(tiff[kCGImagePropertyTIFFMake] as? String == "Camera")
        #expect(tiff[kCGImagePropertyTIFFCompression] as? Int == 5)
    }

    @Test("annotations stay at the selected preview position", arguments: [0, 90, 180, 270])
    func rotatedPDFAnnotations(rotation: Int) throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let output = folder.url.appendingPathComponent("page.pdf")
        var bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        let context = try #require(CGContext(output as CFURL, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.endPDFPage()
        context.closePDF()
        let document = try PDFKitEngine.open(output)
        let page = try #require(document.page(at: 0))
        page.rotation = rotation
        PDFPageEditing.annotate(document, with: [Annotation(
            kind: .rectangle, points: [UnitPoint(x: 0.1, y: 0.1), UnitPoint(x: 0.3, y: 0.3)],
            color: "#FF0000", weight: 0.01
        )])
        let rendered = try PDFPageImageExporter.render(page, dpi: 72)
        let bitmap = NSBitmapImageRep(cgImage: rendered)
        var redPixels: [CGPoint] = []
        for y in 0..<rendered.height {
            for x in 0..<rendered.width {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.redComponent > 0.7, color.greenComponent < 0.3, color.blueComponent < 0.3 else { continue }
                redPixels.append(CGPoint(x: x, y: y))
            }
        }
        let left = try #require(redPixels.map(\.x).min()) / Double(rendered.width)
        let top = try #require(redPixels.map(\.y).min()) / Double(rendered.height)
        let right = try #require(redPixels.map(\.x).max()) / Double(rendered.width)
        let bottom = try #require(redPixels.map(\.y).max()) / Double(rendered.height)
        #expect(abs(left - 0.1) < 0.02 && abs(top - 0.1) < 0.02)
        #expect(abs(right - 0.3) < 0.02 && abs(bottom - 0.3) < 0.02)
    }
}

@Suite("FFmpeg output ownership")
struct FFmpegOutputOwnershipTests {
    private func helper(in folder: TemporaryDirectory, body: String) throws -> URL {
        let script = try folder.file("helper", contents: "#!/bin/sh\n" + body)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return script
    }

    @Test("an existing destination is preserved before launching")
    func existingDestination() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let output = try folder.file("out.mp4", contents: "existing")
        await #expect(throws: JobError.destinationOccupied) {
            try await FFmpegRunner.run(binary: URL(fileURLWithPath: "/usr/bin/false"),
                                      arguments: [FFmpegRunner.hardwareEncoder, output.path]) { _ in }
        }
        #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
    }

    @Test("a retry replaces only its private partial file")
    func retry() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let script = try helper(in: folder, body: """
            for output do :; done
            state="$(dirname "$0")/attempted"
            if [ ! -e "$state" ]; then
                printf partial > "$output"
                touch "$state"
                exit 1
            fi
            [ ! -e "$output" ] || exit 2
            printf complete > "$output"
            """)
        let output = folder.url.appendingPathComponent("out.mp4")
        try await FFmpegRunner.run(binary: script, arguments: [FFmpegRunner.hardwareEncoder, output.path]) { _ in }
        #expect(try String(contentsOf: output, encoding: .utf8) == "complete")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted()
            == ["attempted", "helper", "out.mp4"])
    }

    @Test("a competing writer is preserved when publishing")
    func concurrentDestination() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let script = try helper(in: folder, body: """
            for output do :; done
            printf competitor > "$(dirname "$0")/out.mp4"
            printf ours > "$output"
            """)
        let output = folder.url.appendingPathComponent("out.mp4")
        await #expect(throws: JobError.destinationOccupied) {
            try await FFmpegRunner.run(binary: script, arguments: [output.path]) { _ in }
        }
        #expect(try String(contentsOf: output, encoding: .utf8) == "competitor")
    }

    @Test("exit zero without a nonempty output is a failure")
    func emptyOutput() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let output = folder.url.appendingPathComponent("out.png")
        await #expect(throws: JobError.failed) {
            try await FFmpegRunner.run(binary: URL(fileURLWithPath: "/usr/bin/true"), arguments: [output.path]) { _ in }
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }
}
