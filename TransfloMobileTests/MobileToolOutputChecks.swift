import AVFoundation
import Foundation
import ImageIO
import PDFKit
import Testing
import TransfloDomain
@testable import TransfloMobile
import UIKit

/// Assertions are about content and the requested edit, not only job completion.
enum MobileToolOutputChecks {
    static func verify(
        _ outputs: [URL], pair: MobileToolMatrixTests.Pair, source: URL, original: Data
    ) async throws {
        if [.readCode, .describeImage].contains(pair.tool) {
            #expect(outputs.isEmpty)
            if pair.tool == .readCode {
                #expect(UIPasteboard.general.string?.contains("https://transflo.example/qa") == true)
            } else {
                #expect(UIPasteboard.general.string?.isEmpty == false)
            }
            return
        }
        #expect(!outputs.isEmpty)
        for file in outputs {
            #expect(file != source && FileManager.default.fileExists(atPath: file.path))
            if pair.tool == .rename {
                #expect(file.deletingPathExtension().lastPathComponent == "QA-1")
                #expect(try Data(contentsOf: file) == original)
            } else if file.pathExtension == "pdf" {
                try pdf(file, tool: pair.tool)
            } else if ["mp4", "mov", "m4a", "wav", "aiff", "mp3", "flac"].contains(file.pathExtension) {
                try await media(file, pair: pair)
            } else if file.pathExtension == "txt" {
                #expect(try String(contentsOf: file, encoding: .utf8).contains("TRANSFLO"))
            } else {
                try image(file, tool: pair.tool)
            }
        }
        if pair.tool == .split { #expect(outputs.count == 3) }
        if pair.tool == .compress {
            #expect(try Data(contentsOf: #require(outputs.first)).count <= original.count)
        }
    }

    private static func image(_ file: URL, tool: ToolKind) throws {
        let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        switch tool {
        case .resize, .crop: #expect(image.width == 128 && image.height == 128)
        case .upscale: #expect(image.width == 512 && image.height == 512)
        case .collage: #expect(image.width >= 512)
        case .editMetadata:
            let metadata = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil))
            #expect(String(describing: metadata).contains("QA Title"))
        default: #expect(image.width > 0 && image.height > 0)
        }
    }

    private static func pdf(_ file: URL, tool: ToolKind) throws {
        let document = try #require(PDFDocument(url: file))
        switch tool {
        case .merge: #expect(document.pageCount == 6)
        case .imagesToPDF: #expect(document.pageCount == 2)
        case .split, .extractPages: #expect(document.pageCount == 1)
        case .reorganizePages: #expect(document.page(at: 0)?.string?.contains("Page 3") == true)
        case .editMetadata:
            #expect(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String == "QA Title")
        case .redact:
            #expect(document.page(at: 0)?.string?.contains("Page 1") == true)
            #expect(document.page(at: 1)?.string?.contains("Page 2") != true)
            #expect(document.page(at: 2)?.string?.contains("Page 3") == true)
        default: #expect(document.pageCount == 3)
        }
        if tool == .extractPages { #expect(document.string?.contains("Page 2") == true) }
    }

    private static func media(_ file: URL, pair: MobileToolMatrixTests.Pair) async throws {
        let asset = AVURLAsset(url: file)
        let duration = try await asset.load(.duration).seconds
        let expected: Double
        switch pair.tool {
        case .trim: expected = 2
        case .changeSpeed: expected = 1.5
        case .split: expected = 1
        case .merge: expected = 6
        default: expected = 3
        }
        #expect(abs(duration - expected) < 0.25)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        #expect(pair.tool == .mute ? audio.isEmpty : !audio.isEmpty)
        if ["mp4", "mov"].contains(pair.format.rawValue) {
            #expect(try await !asset.loadTracks(withMediaType: .video).isEmpty)
        }
    }
}
