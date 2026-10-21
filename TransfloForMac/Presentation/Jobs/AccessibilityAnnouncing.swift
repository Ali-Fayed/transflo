/// Speaks a short message through VoiceOver, without moving focus.
protocol AccessibilityAnnouncing {
    func announce(_ message: String)
}
