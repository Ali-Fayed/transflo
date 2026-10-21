import AppKit
import TransfloDomain
import TransfloSystem

/// Receives file drags over the wheel and reports positions relative to the wheel center (y up).
/// In keyboard mode it also takes keys, clicks and pointer movement.
final class WheelDropView: NSView {
    var onHover: ((WheelPoint?) -> Bool)?
    var onDrop: ((WheelPoint) -> Bool)?
    var onPromisedDrop: ((WheelPoint, @escaping PromisedFileDelivery) -> Bool)?
    var onKey: ((WheelKeyCommand) -> Void)?
    var onClick: ((WheelPoint) -> Bool)?
    var onPointer: ((WheelPoint) -> Void)?
    /// Keyboard mode only: plain pointer movement highlights wedges. During a drag the drag
    /// callbacks do that, and a resting cursor must not disturb the highlight.
    var tracksPointer = false
    private var heldModifiers: NSEvent.ModifierFlags = []
    private var clickPoint: WheelPoint?

    private static let steps: [UInt16: Bool] = [124: true, 125: true, 123: false, 126: false]
    private static let confirmKeys: Set<UInt16> = [36, 76]
    private static let escapeKey: UInt16 = 53
    private static let modifiers: [(NSEvent.ModifierFlags, ModifierKey)] = [
        (.shift, .shift), (.command, .command), (.control, .control), (.option, .option)
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL] + PromisedFiles.draggedTypes)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WheelDropView is created in code only")
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let clockwise = Self.steps[event.keyCode] {
            onKey?(.step(clockwise: clockwise))
        } else if Self.confirmKeys.contains(event.keyCode) {
            onKey?(.confirm)
        } else if event.keyCode == Self.escapeKey {
            onKey?(.cancel)
        } else {
            super.keyDown(with: event)
        }
    }

    /// Reports a modifier the moment it goes down (a tap switches wheels).
    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let pressed = flags.subtracting(heldModifiers)
        heldModifiers = flags
        if let key = Self.modifiers.first(where: { pressed.contains($0.0) })?.1 {
            onKey?(.modifier(key))
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard tracksPointer else { return }
        onPointer?(offset(of: event.locationInWindow))
    }

    override func mouseDown(with event: NSEvent) {
        let point = offset(of: event.locationInWindow)
        clickPoint = point
        onPointer?(point)
    }

    override func mouseUp(with event: NSEvent) {
        guard let point = clickPoint else { return }
        clickPoint = nil
        _ = onClick?(point)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover(sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        _ = onHover?(nil)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let hasFiles = pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let promises = hasFiles ? [] : PromisedFiles.receivers(on: pasteboard)
        guard !promises.isEmpty else { return onDrop?(offset(of: sender.draggingLocation)) ?? false }
        return onPromisedDrop?(offset(of: sender.draggingLocation)) { completion in
            PromisedFiles.receive(promises, completion: completion)
        } ?? false
    }

    /// `.copy` only over a wedge, so the original is never moved and elsewhere shows "no drop".
    private func hover(_ sender: any NSDraggingInfo) -> NSDragOperation {
        onHover?(offset(of: sender.draggingLocation)) == true ? .copy : []
    }

    private func offset(of windowLocation: CGPoint) -> WheelPoint {
        let location = convert(windowLocation, from: nil)
        return WheelPoint(x: location.x - bounds.midX, y: location.y - bounds.midY)
    }
}
