import AVFoundation
import Foundation
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile video compression")
struct MobileVideoCompressionTests {
    @Test("video selections offer Compress and the native media tools, but unknown files get nothing")
    func catalog() throws {
        let conversions = MobileConversionFactory()
        let factory = MobileToolFactory(formats: conversions.catalog,
                                        suffixes: LocalizedToolSuffixes(language: .english))
        let mp4 = try #require(conversions.catalog.format(FormatID("mp4")))
        #expect(factory.engines.contains { $0.canRun(.compress, on: [mp4]) })
        #expect(factory.engines.contains { $0.canRun(.trim, on: [mp4]) })
        #expect(!factory.engines.contains { $0.canRun(.normalize, on: [mp4]) })
        #expect(!factory.engines.contains { $0.canRun(.compress, on: [nil]) })
    }

    @Test("all video presets export playable video, retain audio and preserve the input")
    func presets() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let video = root.appendingPathComponent("video.mp4")
        try await MobilePreviewVideo.write(to: video)
        let source = try await addAudio(to: video, in: root)
        let conversions = MobileConversionFactory()
        let mov = try #require(conversions.catalog.format(FormatID("mov")))
        let converted = try await conversions.makeRunner().run(
            WheelOption(.format(mov)), on: [source], progress: { _ in }
        )
        let movie = try #require(converted.first)
        let factory = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                        suffixes: LocalizedToolSuffixes(language: .english))
        for (input, index, maxEdge) in [(source, 0, 1920.0), (source, 1, 1280.0),
                                        (source, 2, 640.0), (movie, 1, 1280.0)] {
            let original = try Data(contentsOf: input)
            let editor = MobileToolEditorModel(tool: .compress, items: [input])
            await editor.load()
            #expect(editor.isVideo && editor.thumbnail != nil && editor.isValid)
            editor.compression = index
            let outputs = try await factory.makeRunner().run(
                WheelOption(.tool(.compress), settings: editor.settings), on: [input], progress: { _ in }
            )
            let output = try #require(outputs.first)
            #expect(output != input && output.pathExtension == "mp4")
            let asset = AVURLAsset(url: output)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let track = try #require(tracks.first)
            let size = try await track.load(.naturalSize)
            #expect(max(size.width, size.height) <= maxEdge)
            #expect(try await asset.load(.duration).seconds > 1.5)
            #expect(try await !asset.loadTracks(withMediaType: .audio).isEmpty)
            #expect(try Data(contentsOf: input) == original)
        }
    }

    @Test("invalid settings, missing sources and cancellation leave no output files")
    func failures() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("missing.mp4")
        let runner = MobileToolFactory(formats: MobileConversionFactory().catalog,
                                       suffixes: LocalizedToolSuffixes(language: .english)).makeRunner()
        await #expect(throws: JobError.unsupported) {
            try await runner.run(
                WheelOption(.tool(.compress), settings: ToolSettings.none), on: [source], progress: { _ in }
            )
        }
        await #expect(throws: JobError.sourceMissing) {
            try await runner.run(WheelOption(.tool(.compress)), on: [source], progress: { _ in })
        }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await runner.run(WheelOption(.tool(.compress)), on: [source], progress: { _ in })
        }
        await #expect(throws: JobError.cancelled) { try await cancelled.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    private func addAudio(to video: URL, in root: URL) async throws -> URL {
        let audio = root.appendingPathComponent("tone.wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88_200))
        buffer.frameLength = 88_200
        let samples = try #require(buffer.floatChannelData?[0])
        for index in 0..<88_200 { samples[index] = Float(sin(Double(index) * 2 * .pi * 440 / 44_100)) * 0.1 }
        do {
            let file = try AVAudioFile(forWriting: audio, settings: format.settings)
            try file.write(from: buffer)
        }
        let composition = AVMutableComposition()
        for (url, type) in [(video, AVMediaType.video), (audio, AVMediaType.audio)] {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: type)
            let source = try #require(tracks.first)
            let target = try #require(composition.addMutableTrack(withMediaType: type,
                                                                 preferredTrackID: kCMPersistentTrackID_Invalid))
            try target.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)),
                                       of: source, at: .zero)
        }
        let output = root.appendingPathComponent("with-audio.mp4")
        let session = try #require(AVAssetExportSession(asset: composition,
                                                        presetName: AVAssetExportPresetHighestQuality))
        session.outputURL = output
        session.outputFileType = .mp4
        await session.export()
        #expect(session.status == .completed)
        return output
    }
}
