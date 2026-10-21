/// Turns on playback audio for the editors' previews, and back off when a preview closes.
protocol MobileAudioSessionControlling: Sendable {
    func activate()
    func deactivate()
}
