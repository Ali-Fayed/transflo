import AVFoundation
import Observation
import SwiftUI
import TransfloDomain

/// Source audition shares the selected time range and rate with the editor.
struct MediaAuditionView: View {
    let url: URL
    var start: Double = 0
    var end: Double?
    var rate: Double = 1
    var previews: (any ToolPreviewProviding)?
    @State private var waveform: Data?
    @State private var playback = MediaAuditionController()
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(.mediaSourcePreview, style: .headline)
            if ["mp4", "mov", "mkv", "webm", "avi", "wmv"].contains(url.pathExtension.lowercased()),
               let player = playback.player {
                NativeMediaPlayer(player: player).frame(height: 150)
            }
            if let waveform { AppPreviewImage(data: waveform).frame(height: 64) }
            HStack {
                AppButton(key: .mediaPlaySelection, variant: .tertiary) {
                    playback.play(start: start, end: end, rate: rate)
                }
                AppButton(key: .mediaStop, variant: .tertiary) { playback.stop() }
                Spacer()
                AppText(verbatim: TimeLabel.text(playback.position), style: .caption).monospacedDigit()
            }
        }
        .task(id: url) { playback.load(url); waveform = await previews?.waveform(of: url) }
        .onDisappear { playback.release() }
        .onChange(of: start) { playback.stop() }
        .onChange(of: end) { playback.stop() }
        .onChange(of: rate) { playback.stop() }
    }
}

@MainActor @Observable
final class MediaAuditionController {
    private(set) var position = 0.0
    private(set) var player: AVPlayer?
    private static weak var active: MediaAuditionController?
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var end: Double?
    func load(_ url: URL) {
        release()
        let player = AVPlayer(url: url)
        self.player = player
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
                                                   queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.position = time.seconds.isFinite ? time.seconds : 0
                if let end = self.end, self.position >= end { self.stop() }
            }
        }
    }
    func play(start: Double, end: Double?, rate: Double) {
        guard start.isFinite, start >= 0, rate.isFinite, (0.25...4).contains(rate) else { return }
        if Self.active !== self { Self.active?.stop() }
        Self.active = self
        self.end = end
        player?.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player?.playImmediately(atRate: Float(rate))
    }
    func stop() { player?.pause() }
    func release() {
        player?.pause()
        if let observer { player?.removeTimeObserver(observer) }
        observer = nil; player = nil; position = 0
        if Self.active === self { Self.active = nil }
    }
}
