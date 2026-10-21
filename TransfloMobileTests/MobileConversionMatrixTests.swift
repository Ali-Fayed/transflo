import AVFoundation
import Foundation
import ImageIO
import PDFKit
import Testing
import TransfloDomain
@testable import TransfloMobile
import UIKit

/// Runs the actual catalog, not a hand-maintained subset. Each route gets an isolated input copy.
@Suite("Every advertised mobile conversion", .serialized)
struct MobileConversionMatrixTests {
    static var routes: [ConversionPath] { MobileConversionFactory().catalog.paths }

    @Test("decodable, semantically valid output and unchanged source", arguments: await MainActor.run { routes })
    func convert(path: ConversionPath) async throws {
        let catalog = MobileConversionFactory().catalog
        let sourceFormat = try #require(catalog.format(path.source))
        let target = try #require(catalog.format(path.target))
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let fixture = try MobileMatrixFixtures.file(path.source.rawValue)
        let source = workspace.appendingPathComponent(fixture.lastPathComponent)
        try FileManager.default.copyItem(at: fixture, to: source)
        let original = try Data(contentsOf: source)
        let outputs = try await MobileConversionFactory().makeRunner().run(
            WheelOption(.format(target)), on: [source], progress: { _ in })
        let files = try outputs.flatMap { url -> [URL] in
            if (try url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true {
                return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            }
            return [url]
        }
        #expect(!files.isEmpty, "No outputs for \(path.source.rawValue) → \(path.target.rawValue)")
        #expect(try Data(contentsOf: source) == original)
        #expect(files.allSatisfy { $0 != source })
        for file in files { try await verify(file, sourceFormat: sourceFormat, target: target) }
        if sourceFormat.id.rawValue == "pdf", target.family == .image { #expect(files.count == 3) }
        print("MOBILE_ROUTE_PASS \(path.source.rawValue) -> \(path.target.rawValue)")
    }

    private func verify(_ file: URL, sourceFormat: FormatDescriptor, target: FormatDescriptor) async throws {
        #expect(try !Data(contentsOf: file).isEmpty)
        switch target.family {
        case .image:
            try verifyImage(file, animated: sourceFormat.family == .video)
        case .audio:
            let audio = try AVAudioFile(forReading: file)
            let duration = Double(audio.length) / audio.processingFormat.sampleRate
            #expect(abs(duration - 3) < 0.25 && audio.processingFormat.channelCount == 1)
        case .video:
            let asset = AVURLAsset(url: file)
            #expect(abs(try await asset.load(.duration).seconds - 3) < 0.25)
            #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
            #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
        case .document where target.id.rawValue == "pdf":
            let pdf = try #require(PDFDocument(url: file))
            #expect(pdf.pageCount >= 1)
            #expect(pdf.page(at: 0)?.bounds(for: .mediaBox).width ?? 0 > 0)
            if sourceFormat.family != .image { #expect(pdf.string?.contains("TRANSFLO") == true) }
        default:
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(text.contains("TRANSFLO"))
            if target.id.rawValue == "vtt" { #expect(text.hasPrefix("WEBVTT")) }
            if target.id.rawValue == "srt" { #expect(text.contains("00:00:00,000")) }
            if target.id.rawValue == "html" { #expect(text.lowercased().contains("<html")) }
        }
    }

    private func verifyImage(_ url: URL, animated: Bool) throws {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        if animated { #expect(CGImageSourceGetCount(source) >= 2) }
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width > 0 && image.height > 0)
        let pixels = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                           bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        pixels.draw(image, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        let data = try #require(pixels.data).assumingMemoryBound(to: UInt8.self)
        let colors = Set((0..<64).map { index in
            Int(data[index * 4]) << 16 | Int(data[index * 4 + 1]) << 8 | Int(data[index * 4 + 2])
        })
        #expect(colors.count > 1, "The decoded image must retain visible fixture content")
    }
}
