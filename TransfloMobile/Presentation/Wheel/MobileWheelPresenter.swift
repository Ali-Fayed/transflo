import Observation
import os
import TransfloDomain

/// Shows the wheel in the app's own window on iPhone and iPad, centered on screen, and forwards
/// taps on it as offsets from the wheel's center (y up), like clicks on the Mac.
@Observable
final class MobileWheelPresenter: WheelPresenting {
    private(set) var isShown = false

    @ObservationIgnored var onHover: ((WheelPoint?) -> Bool)?
    @ObservationIgnored var onDrop: ((WheelPoint) -> Bool)?
    @ObservationIgnored var onPromisedDrop: ((WheelPoint, @escaping PromisedFileDelivery) -> Bool)?
    @ObservationIgnored var onKey: ((WheelKeyCommand) -> Void)?
    @ObservationIgnored var onPointer: ((WheelPoint) -> Void)?
    @ObservationIgnored var onClick: ((WheelPoint) -> Bool)?

    /// The wheel opens centered whatever `point` is: on a phone, there is no pointer to follow.
    func show(at point: WheelPoint) {
        isShown = true
    }

    func showInteractive(at point: WheelPoint) {
        show(at: point)
    }

    func hide() {
        isShown = false
    }

    /// A tap `offset` from the wheel's center. Returns whether it hit an option or a page control.
    @discardableResult
    func tap(at offset: WheelPoint) -> Bool {
        let hit = onClick?(offset) ?? false
        logger.debug("Wheel tap at \(offset.x), \(offset.y): \(hit ? "option" : "nothing")")
        return hit
    }

    @ObservationIgnored private let logger = Logger(subsystem: "com.transflo.app", category: "Wheel")

    /// A finger on the wheel highlights the wedge under it, as the pointer does on the Mac.
    func touch(at offset: WheelPoint) {
        onPointer?(offset)
    }
}
