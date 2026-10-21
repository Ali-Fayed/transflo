import AVFoundation
import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile
import UIKit

@Suite("Mobile native formats")
struct MobileNativeConversionTests {
    @Test("a real PDF exports readable text and a page image", arguments: ["txt", "png"])
    func pdf(target: String) async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("document.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 100))
            .writePDF(to: source) { context in
                context.beginPage()
                ("Transflo mobile PDF" as NSString).draw(at: CGPoint(x: 12, y: 20),
                                                        withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            }
        let output = try await convert(source, to: target)
        if target == "txt" {
            #expect(try String(contentsOf: output, encoding: .utf8).contains("Transflo mobile PDF"))
        } else {
            #expect(UIImage(contentsOfFile: output.path) != nil)
        }
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("SRT converts to a WebVTT file with its caption text")
    func subtitles() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("captions.srt")
        try "1\n00:00:00,000 --> 00:00:01,000\nHello from Transflo\n"
            .write(to: source, atomically: true, encoding: .utf8)
        let output = try await convert(source, to: "vtt")
        let text = try String(contentsOf: output, encoding: .utf8)
        #expect(text.hasPrefix("WEBVTT") && text.contains("Hello from Transflo"))
    }

    @Test("native WAV audio converts to a playable M4A")
    func audio() async throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("audio.wav")
        try writeAudio(to: source)
        let output = try await convert(source, to: "m4a")
        let audio = try AVAudioFile(forReading: output)
        #expect(audio.length > 0 && audio.processingFormat.channelCount == 1)
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func convert(_ source: URL, to target: String) async throws -> URL {
        let factory = MobileConversionFactory()
        let format = try #require(factory.catalog.format(FormatID(target)))
        let outputs = try await factory.makeRunner().run(WheelOption(.format(format)), on: [source], progress: { _ in })
        return try #require(outputs.first)
    }

    private func writeAudio(to url: URL) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410))
        buffer.frameLength = 4_410
        let channel = try #require(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) { channel[index] = 0 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
