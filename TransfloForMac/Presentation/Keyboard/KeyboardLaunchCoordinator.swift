import Foundation
import TransfloDomain

/// The no-drag way in: the global hotkey reads Finder's selection, and the "Open in Transflo"
/// Service hands over its files; either opens the keyboard-driven wheel at the pointer.
final class KeyboardLaunchCoordinator {
    private let hotKeys: any HotKeyRegistering
    private let selection: any FinderSelectionReading
    private let wheel: any KeyboardWheelOpening
    private let hints: any HintPresenting
    private let pointer: () -> WheelPoint
    private let clipboard: (any ClipboardFilesReading)?

    init(
        hotKeys: any HotKeyRegistering,
        selection: any FinderSelectionReading,
        wheel: any KeyboardWheelOpening,
        hints: any HintPresenting,
        pointer: @escaping () -> WheelPoint,
        clipboard: (any ClipboardFilesReading)? = nil
    ) {
        self.hotKeys = hotKeys
        self.selection = selection
        self.wheel = wheel
        self.hints = hints
        self.pointer = pointer
        self.clipboard = clipboard
    }

    /// Convert Clipboard: opens the wheel for the copied files or image, or says there is nothing to take.
    func openClipboard() {
        let point = pointer()
        guard let clipboard else { return }
        do throws(JobError) {
            let items = try clipboard.files()
            guard !items.isEmpty else {
                hints.showHint(.hintClipboardEmpty, near: point)
                return
            }
            open(items, at: point)
        } catch {
            hints.showHint(JobPresentation.message(for: error), near: point)
        }
    }

    /// Listens for `hotKey`. Returns `false` if the system refused it (another app owns it).
    @discardableResult
    func start(hotKey: HotKey) -> Bool {
        hotKeys.register(hotKey) { [weak self] in
            Task { await self?.openFinderSelection() }
        }
    }

    func stop() {
        hotKeys.unregister()
    }

    /// Opens the wheel for Finder's selection, or explains why it can't.
    func openFinderSelection() async {
        let point = pointer()
        do throws(JobError) {
            open(try await selection.selection(), at: point)
        } catch .automationDenied {
            hints.showHint(.hintFinderAutomation, near: point)
        } catch {
            hints.showHint(.errorFailed, near: point)
        }
    }

    /// Opens the wheel for files handed over directly (the Service).
    func open(_ items: [URL]) {
        open(items, at: pointer())
    }

    private func open(_ items: [URL], at point: WheelPoint) {
        guard !items.isEmpty else {
            hints.showHint(.hintSelectInFinder, near: point)
            return
        }
        if !wheel.openForKeyboard(items: items, at: point) {
            hints.showHint(.errorActionUnavailable, near: point)
        }
    }
}
