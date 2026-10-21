#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Posts a high-priority VoiceOver announcement (ignored when VoiceOver is off).
struct SystemAccessibilityAnnouncer: AccessibilityAnnouncing {
    func announce(_ message: String) {
        #if os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high.rawValue
        ])
        #else
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
