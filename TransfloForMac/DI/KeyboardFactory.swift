import AppKit
import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the no-drag path: the hotkey launcher and the Finder Service provider.
struct KeyboardFactory {
    let launcher: KeyboardLaunchCoordinator
    let serviceProvider: FinderServiceProvider

    init(wheel: any KeyboardWheelOpening, hints: any HintPresenting) {
        launcher = KeyboardLaunchCoordinator(
            hotKeys: CarbonHotKeyCenter(),
            selection: FinderSelectionReader(),
            wheel: wheel,
            hints: hints,
            pointer: { WheelPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y) },
            clipboard: PasteboardClipboardReader()
        )
        serviceProvider = FinderServiceProvider(launcher: launcher)
    }
}
