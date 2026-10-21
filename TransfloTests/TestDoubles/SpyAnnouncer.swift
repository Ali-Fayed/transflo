@testable import Transflo

/// Records announcements.
final class SpyAnnouncer: AccessibilityAnnouncing {
    private(set) var messages: [String] = []

    func announce(_ message: String) {
        messages.append(message)
    }
}
