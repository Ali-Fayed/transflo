import Foundation

/// Drag lifecycle events delivered to the wheel feature.
public enum DragEvent: Sendable, Equatable {
    /// A file drag started; `items` are the dragged file URLs.
    case began(items: [URL])
    /// The user asked for a wheel at `point`.
    case wheelRequested(WheelKind, at: WheelPoint)
    /// The mouse was released.
    case ended
}
