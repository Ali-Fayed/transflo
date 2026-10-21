import Foundation
import TransfloDomain

/// Reads the system state the drag tracker needs.
@MainActor
public protocol DragSampling: AnyObject {
    /// The current mouse, pasteboard, modifier and pointer state.
    func sample() -> DragSample
    /// File URLs on the drag pasteboard (empty for non-file drags).
    func draggedFileURLs() -> [URL]
}
