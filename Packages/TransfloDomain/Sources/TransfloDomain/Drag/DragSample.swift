/// One poll of the system state while the mouse button may be down.
public struct DragSample: Sendable, Equatable {
    /// Whether the primary mouse button is pressed.
    public let isMouseDown: Bool
    /// The drag pasteboard's change count; it changes when any app starts a drag.
    public let pasteboardChangeCount: Int
    /// Modifiers held at sample time.
    public let modifiers: Set<ModifierKey>
    /// Pointer location in screen space.
    public let location: WheelPoint

    public init(isMouseDown: Bool, pasteboardChangeCount: Int, modifiers: Set<ModifierKey>, location: WheelPoint) {
        self.isMouseDown = isMouseDown
        self.pasteboardChangeCount = pasteboardChangeCount
        self.modifiers = modifiers
        self.location = location
    }
}
