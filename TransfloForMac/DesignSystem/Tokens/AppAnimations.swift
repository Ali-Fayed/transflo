import SwiftUI

/// Shared motion curves.
enum AppAnimations {
    private static var reduced: Bool {
        InterfaceStyle.shared.preferences.reduceMotion || AppPlatform.systemReducesMotion
    }

    static var onboarding: Animation? { reduced ? nil : .easeInOut(duration: 0.25) }
    /// Content settling into place when a Getting Started page opens.
    static var entrance: Animation? { reduced ? nil : .spring(response: 0.55, dampingFraction: 0.86) }
    /// Delay between consecutive elements of one entrance, in seconds.
    static let entranceStep = 0.07
    /// A single wheel reveal at launch, never a repeating loading animation.
    static var brandReveal: Animation? { reduced ? nil : .easeOut(duration: 0.65) }
    static let launchDuration: Duration = .milliseconds(650)
    /// The app icon and sample wheels landing with a little bounce.
    static var heroPop: Animation? { reduced ? nil : .spring(response: 0.6, dampingFraction: 0.62) }
    /// A keycap demonstrating a tap: a quick press after a pause, then a springy release.
    static var keycapPress: Animation? { reduced ? nil : .snappy(duration: 0.12).delay(1.4) }
    static var keycapRelease: Animation? { reduced ? nil : .spring(response: 0.3, dampingFraction: 0.5) }
    #if os(macOS)
    /// How the Getting Started window itself appears.
    static var windowPresentation: NSWindow.AnimationBehavior { reduced ? .none : .alertPanel }
    #endif

    /// Default transition for state changes inside a window.
    static var standard: Animation? { reduced ? nil : .snappy(duration: 0.2) }
    /// The wheel popping open under the cursor.
    static var wheelAppear: Animation? { reduced ? nil : .spring(response: 0.26, dampingFraction: 0.78) }
    /// Wedge highlight following the pointer; fast enough to feel attached to it.
    static var wheelHighlight: Animation? { reduced ? nil : .snappy(duration: 0.1) }
    /// The wheel folding into the result disc after a drop.
    static var resultEnter: Animation? { reduced ? nil : .spring(response: 0.42, dampingFraction: 0.78) }
    /// The check or cross drawing itself in when a job ends.
    static var resultGlyph: Animation? { reduced ? nil : .easeOut(duration: 0.32) }
    /// Success: a short springy pulse. Failure: a quick side-to-side shake. Both off with Reduce Motion.
    static var resultPulse: Bool { !reduced }
    /// The disc fading away once the result has been seen.
    static var resultExit: Animation? { reduced ? nil : .easeIn(duration: 0.25) }
    /// A waiting job's arc turning before progress is known.
    static var resultSpin: Animation? { reduced ? nil : .linear(duration: 1).repeatForever(autoreverses: false) }
    /// A checkbox ticking.
    static var checkbox: Animation? { reduced ? nil : .snappy(duration: 0.16) }
    /// Progress ring filling as a job advances.
    static var progress: Animation? { reduced ? nil : .linear(duration: 0.15) }
}
