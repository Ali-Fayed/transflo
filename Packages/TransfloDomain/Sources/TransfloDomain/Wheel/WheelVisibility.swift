/// Which wedges the user hid in Settings › Wheel, by `WheelOption.id` (for example `format.bmp`,
/// `tool.crop`, `action.terminal`). Formats are keyed by format alone, so hiding one hides it on every
/// Convert wheel whatever the dragged file.
public struct WheelVisibility: Sendable, Equatable, Codable {
    public private(set) var hiddenOptionIDs: Set<String>

    public init(hiddenOptionIDs: Set<String> = []) {
        self.hiddenOptionIDs = hiddenOptionIDs
    }

    /// Nothing hidden: every wheel shows everything that applies.
    public static let standard = WheelVisibility()

    public func isVisible(_ option: WheelOption) -> Bool {
        !hiddenOptionIDs.contains(option.id)
    }

    /// Shows or hides one option.
    public mutating func set(_ option: WheelOption, visible: Bool) {
        if visible { hiddenOptionIDs.remove(option.id) } else { hiddenOptionIDs.insert(option.id) }
    }

    /// Shows or hides several options at once (Show All / Hide All).
    public mutating func set(_ options: [WheelOption], visible: Bool) {
        options.forEach { set($0, visible: visible) }
    }
}
