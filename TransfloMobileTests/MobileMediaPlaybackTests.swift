import AVFoundation
import Foundation
import Testing
@testable import TransfloMobile

@Suite("Mobile editor playback", .serialized)
struct MobileMediaPlaybackTests {
    @Test("a real video seeks, previews a selected range at speed, and releases its item on close")
    func playback() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("preview.mp4")
        try await MobilePreviewVideo.write(to: url)
        let model = MobileMediaPlayback()
        await model.load(url)
        #expect(model.duration > 1.5 && !model.failed && !model.isPlaying)
        #expect(model.player.currentItem != nil)
        model.seek(-50)
        #expect(model.position == 0)
        model.seek(50)
        #expect(model.position == model.duration)
        model.toggle(start: 0.25, end: 1.25, rate: 2)
        #expect(model.isPlaying && model.position == 0.25)
        for _ in 0..<60 {
            try await Task.sleep(for: .milliseconds(50))
            if !model.isPlaying { break }
        }
        #expect(model.position >= 1.2 && !model.isPlaying)
        model.stop()
        #expect(model.player.currentItem == nil && model.duration == 0 && !model.isPlaying)
    }

    @Test("an unavailable video shows a recoverable preview error and never starts playing")
    func missing() async {
        let model = MobileMediaPlayback()
        await model.load(URL(fileURLWithPath: "/nonexistent/transflo-preview.mp4"))
        #expect(model.failed && model.player.currentItem == nil)
        model.toggle(start: 0, end: 1, rate: 1)
        #expect(!model.isPlaying)
        model.stop()
    }
    @Test("skip preserves playback, respects the trim range, and a newly loaded file starts at zero")
    func skipAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("preview.mp4")
        try await MobilePreviewVideo.write(to: url, duration: 12)
        let model = MobileMediaPlayback()
        await model.load(url)
        model.toggle(start: 1, end: 11, rate: 1)
        model.skip(5, start: 1, end: 11)
        #expect(model.isPlaying && model.position >= 5.9 && model.position <= 6.1)
        try await Task.sleep(for: .milliseconds(250))
        #expect(model.isPlaying && model.player.rate > 0)
        model.skip(50, start: 1, end: 11)
        #expect(model.isPlaying && model.position < 11)
        model.skip(-50, start: 1, end: 11)
        #expect(model.isPlaying && model.position == 1)
        model.pause()
        model.skip(5)
        #expect(!model.isPlaying)
        await model.load(url)
        #expect(model.position == 0 && !model.isPlaying)
        model.stop()
    }

    @Test("audio previews enable playback audio and also open at the beginning")
    func audio() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000))
        buffer.frameLength = 96000
        let samples = try #require(buffer.floatChannelData?[0])
        for frame in 0..<96000 { samples[frame] = Float(sin(Double(frame) * 440 * 2 * .pi / 48000) * 0.1) }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        let session = SpyAudioSession()
        let model = MobileMediaPlayback(audio: session)
        await model.load(url)
        #expect(!model.failed && model.position == 0)
        model.toggle(start: 0, end: model.duration, rate: 1)
        #expect(model.isPlaying && !model.player.isMuted && model.player.volume > 0)
        model.toggle(start: 0, end: model.duration, rate: 1)
        model.toggle(start: 0, end: model.duration, rate: 1)
        #expect(session.activations == 1)
        model.stop()
        #expect(session.deactivations == 1)
    }

    @Test("the play button follows a pause that didn't come from it")
    func externalPause() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("preview.mp4")
        try await MobilePreviewVideo.write(to: url, duration: 6)
        let model = MobileMediaPlayback(audio: SpyAudioSession())
        await model.load(url)
        model.toggle(start: 0, end: model.duration, rate: 1)
        try await Task.sleep(for: .milliseconds(300))
        // When the full-screen player (or an interruption) pauses playback
        model.player.pause()
        for _ in 0..<40 where model.isPlaying { try await Task.sleep(for: .milliseconds(25)) }
        #expect(!model.isPlaying)
        // And when it resumes on its own controls
        model.player.play()
        for _ in 0..<40 where !model.isPlaying { try await Task.sleep(for: .milliseconds(25)) }
        #expect(model.isPlaying)
        model.stop()
    }
}
