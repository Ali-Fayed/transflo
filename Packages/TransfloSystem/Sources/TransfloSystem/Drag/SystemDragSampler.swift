import AppKit
import TransfloDomain

/// Samples the real mouse, keyboard modifiers and drag pasteboard.
@MainActor
public final class SystemDragSampler: DragSampling {
    private let pasteboard = NSPasteboard(name: .drag)

    public init() {}

    public func sample() -> DragSample {
        let location = NSEvent.mouseLocation
        return DragSample(
            isMouseDown: NSEvent.pressedMouseButtons & 1 == 1,
            pasteboardChangeCount: pasteboard.changeCount,
            modifiers: Self.modifiers(from: NSEvent.modifierFlags),
            location: WheelPoint(x: location.x, y: location.y)
        )
    }

    /// Real files, or placeholders for promised ones (drags from Safari, Photos or Mail).
    public func draggedFileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let files = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return files.isEmpty ? PromisedFiles.placeholders(on: pasteboard) : files
    }

    nonisolated static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<ModifierKey> {
        let mapping: [(NSEvent.ModifierFlags, ModifierKey)] = [
            (.shift, .shift), (.command, .command), (.control, .control), (.option, .option)
        ]
        return Set(mapping.filter { flags.contains($0.0) }.map(\.1))
    }
}
