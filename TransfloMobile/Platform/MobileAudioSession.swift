import AVFoundation

/// Adapter over the shared AVAudioSession. Its calls can block while the audio server is busy, so
/// they run on a serial queue off the main thread; playback starts without waiting for them.
final class MobileAudioSession: MobileAudioSessionControlling, @unchecked Sendable {
    static let shared = MobileAudioSession()

    private let queue = DispatchQueue(label: "com.transflo.audioSession", qos: .userInitiated)

    func activate() {
        queue.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback)
            try? session.setActive(true)
        }
    }

    func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
