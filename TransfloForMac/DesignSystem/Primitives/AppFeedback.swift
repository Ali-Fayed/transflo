#if os(iOS)
import UIKit
#endif

/// Deliberate feedback at action boundaries; the user's feedback preference applies everywhere.
enum AppFeedback {
    static func selection() {
        #if os(iOS)
        guard InterfaceStyle.shared.preferences.wheelHaptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        guard InterfaceStyle.shared.preferences.wheelHaptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
