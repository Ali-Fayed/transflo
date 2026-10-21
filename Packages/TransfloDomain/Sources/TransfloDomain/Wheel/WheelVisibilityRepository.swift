/// Repository for the wedges hidden in Settings › Wheel.
public protocol WheelVisibilityRepository: Sendable {
    /// The stored choice, or `.standard` when nothing was ever hidden or the stored value is unreadable.
    func loadWheelVisibility() -> WheelVisibility
    func saveWheelVisibility(_ visibility: WheelVisibility)
}
