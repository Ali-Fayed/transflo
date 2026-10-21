/// What `DragTracker` concluded from a sample.
public enum DragTrackerOutput: Sendable, Equatable {
    /// A drag started in some app; the caller should inspect the drag pasteboard.
    case began
    /// A bound modifier was pressed during the drag.
    case wheelRequested(WheelKind, at: WheelPoint)
    /// The mouse was released after a tracked drag.
    case ended
}
