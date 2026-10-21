import AppKit

/// Independent sound and trackpad feedback, limited to deliberate selection boundaries.
final class WheelHaptics {
    static let shared = WheelHaptics()
    private var lastFeedback: ContinuousClock.Instant?
    private let isEnabled: () -> Bool
    private let isSoundEnabled: () -> Bool
    private let performSound: () -> Void
    private let now: () -> ContinuousClock.Instant
    private let perform: () -> Void

    init(
        isEnabled: @escaping () -> Bool = { InterfaceStyle.shared.preferences.wheelHaptics },
        now: @escaping () -> ContinuousClock.Instant = { .now },
        isSoundEnabled: @escaping () -> Bool = { InterfaceStyle.shared.preferences.wheelSound },
        performSound: @escaping () -> Void = { WheelHaptics.playTick() },
        perform: @escaping () -> Void = {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    ) {
        self.isEnabled = isEnabled
        self.isSoundEnabled = isSoundEnabled
        self.performSound = performSound
        self.now = now
        self.perform = perform
    }

    private static let tick: NSSound? = {
        guard let url = Bundle.main.url(forResource: "WheelTick", withExtension: "wav") else { return nil }
        let sound = NSSound(contentsOf: url, byReference: false)
        sound?.volume = 0.3
        return sound
    }()

    private static func playTick() {
        tick?.stop()
        tick?.play()
    }

    func selectionChanged() {
        let haptics = isEnabled()
        let sound = isSoundEnabled()
        guard haptics || sound else { return }
        let instant = now()
        if let lastFeedback, instant - lastFeedback < .milliseconds(65) { return }
        lastFeedback = instant
        if haptics { perform() }
        if sound { performSound() }
    }
}
