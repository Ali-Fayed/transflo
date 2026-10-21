import TransfloDomain
import TransfloSystem

/// Applies input preferences live: drag bindings, the wheel hub's key glyph and the hotkey.
/// The Terminal action reads its app from the repository each time, so it needs nothing here.
final class InputPreferencesApplier: InputPreferencesApplying {
    private let dragMonitor: DragMonitor
    private let wheel: WheelViewModel
    private let keyboard: KeyboardLaunchCoordinator
    private let usesHotKey: Bool

    init(dragMonitor: DragMonitor, wheel: WheelViewModel, keyboard: KeyboardLaunchCoordinator, usesHotKey: Bool) {
        self.dragMonitor = dragMonitor
        self.wheel = wheel
        self.keyboard = keyboard
        self.usesHotKey = usesHotKey
    }

    @discardableResult
    func apply(_ preferences: InputPreferences) -> Bool {
        dragMonitor.update(bindings: preferences.wheelKeys)
        wheel.update(bindings: preferences.wheelKeys)
        return usesHotKey ? keyboard.start(hotKey: preferences.hotKey) : true
    }
}
