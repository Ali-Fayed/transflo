@preconcurrency import AVFoundation
import Foundation
import Observation

/// Owns one editor's playback session. No autoplay; leaving the editor releases its media and observer.
/// Play and pause follow the player itself, so the button stays right when playback stops on its own
/// (an interruption, a stall, or the full-screen player's own controls).
@Observable
final class MobileMediaPlayback {
    let player = AVPlayer()
    var isFullScreen = false
    private(set) var position = 0.0
    private(set) var duration = 0.0
    private(set) var loadedURL: URL?
    private(set) var isPlaying = false
    private(set) var failed = false
    @ObservationIgnored private var observer: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private let audio: any MobileAudioSessionControlling
    private var seekID = 0
    private var seeking = false
    private var end = 0.0
    private var start = 0.0
    private var playbackRate: Float = 1
    private var audioActive = false

    init(audio: any MobileAudioSessionControlling = MobileAudioSession.shared) {
        self.audio = audio
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in self?.statusChanged(status) }
        }
    }

    func load(_ url: URL) async {
        stop()
        failed = false
        let asset = AVURLAsset(url: url)
        guard let seconds = try? await asset.load(.duration).seconds,
              seconds.isFinite, seconds > 0, (try? await asset.load(.isPlayable)) == true,
              !Task.isCancelled else {
            failed = !Task.isCancelled
            return
        }
        loadedURL = url
        duration = seconds
        end = seconds
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                                                   queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in self?.update(time.seconds) }
        }
    }

    func toggle(start: Double, end: Double, rate: Double) {
        if isPlaying { pause(); return }
        guard duration > 0, !failed else { return }
        if !audioActive {
            audio.activate()
            audioActive = true
        }
        player.isMuted = false
        player.volume = 1
        self.start = min(max(0, start), duration)
        self.end = min(max(self.start, end), duration)
        if position < self.start || position >= self.end - 0.05 { seek(self.start) }
        playbackRate = Float(min(4, max(0.25, rate)))
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(_ seconds: Double) {
        let finite = seconds.isFinite ? seconds : 0
        position = min(duration, max(0, finite))
        seekID += 1
        let request = seekID
        seeking = true
        player.seek(to: CMTime(seconds: position, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, seekID == request else { return }
                seeking = false
                if isPlaying { player.playImmediately(atRate: playbackRate) }
            }
        }
    }

    /// Seeking while playing resumes at the chosen speed; a paused preview stays paused.
    func skip(_ offset: Double, start: Double = 0, end: Double? = nil) {
        let upper = min(duration, end ?? duration)
        let lower = min(upper, max(0, start))
        seek(min(max(lower, position + offset), max(lower, upper - (isPlaying ? 0.1 : 0))))
    }

    func setRate(_ value: Double) {
        playbackRate = Float(min(4, max(0.25, value)))
        if isPlaying { player.rate = playbackRate }
    }

    func stop() {
        pause()
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
        seekID += 1
        seeking = false
        player.currentItem?.cancelPendingSeeks()
        player.replaceCurrentItem(with: nil)
        position = 0
        duration = 0
        loadedURL = nil
        if audioActive {
            audio.deactivate()
            audioActive = false
        }
    }

    /// Follows play and pause that didn't come from our buttons; a pause during our own seek is only the seek.
    private func statusChanged(_ status: AVPlayer.TimeControlStatus) {
        guard !seeking else { return }
        switch status {
        case .paused where isPlaying: isPlaying = false
        case .playing where !isPlaying: isPlaying = true
        default: break
        }
    }

    private func update(_ seconds: Double) {
        guard seconds.isFinite, !seeking else { return }
        position = min(duration, max(0, seconds))
        if isPlaying, position >= end - 0.03 { pause() }
        if player.currentItem?.status == .failed { failed = true; pause() }
    }
}
