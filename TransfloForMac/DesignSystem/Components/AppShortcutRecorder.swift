import AppKit
import SwiftUI
import TransfloDomain

/// Shows a shortcut; click it, then press the new combination (Esc cancels).
struct AppShortcutRecorder: View {
    @Environment(Localizer.self) private var localizer
    let text: String
    let onRecord: (UInt32, Set<ModifierKey>) -> Void
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            if monitor == nil {
                // Shortcut glyphs read left to right in every language, as in macOS menus.
                AppText(verbatim: text, style: .headline)
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                AppText(.shortcutRecording, color: .accent)
            }
        }
        .buttonStyle(.bordered)
        .accessibilityValue(text)
        .onDisappear(perform: stop)
    }

    private func toggle() {
        guard monitor == nil else {
            stop()
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != Self.escapeKey {
                onRecord(UInt32(event.keyCode), Self.modifiers(event.modifierFlags))
            }
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private static let escapeKey: UInt16 = 53

    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> Set<ModifierKey> {
        let pairs: [(NSEvent.ModifierFlags, ModifierKey)] = [
            (.command, .command), (.option, .option), (.control, .control), (.shift, .shift)
        ]
        return Set(pairs.filter { flags.contains($0.0) }.map(\.1))
    }
}
