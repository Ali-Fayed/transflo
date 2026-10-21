import Foundation
@testable import TransfloMobile

/// Counts audio-session changes instead of touching the real session.
final class SpyAudioSession: MobileAudioSessionControlling, @unchecked Sendable {
    private(set) var activations = 0
    private(set) var deactivations = 0

    func activate() { activations += 1 }
    func deactivate() { deactivations += 1 }
}
