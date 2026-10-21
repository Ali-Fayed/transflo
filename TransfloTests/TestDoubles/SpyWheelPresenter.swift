@testable import Transflo
import TransfloDomain

/// Records show/hide calls and lets tests simulate hover, drop, clicks and keys.
final class SpyWheelPresenter: WheelPresenting {
    var onHover: ((WheelPoint?) -> Bool)?
    var onDrop: ((WheelPoint) -> Bool)?
    var onPromisedDrop: ((WheelPoint, @escaping PromisedFileDelivery) -> Bool)?
    var onKey: ((WheelKeyCommand) -> Void)?
    var onClick: ((WheelPoint) -> Bool)?
    var onPointer: ((WheelPoint) -> Void)?
    private(set) var shownAt: [WheelPoint] = []
    private(set) var interactiveAt: [WheelPoint] = []
    private(set) var hideCount = 0

    func show(at point: WheelPoint) {
        shownAt.append(point)
    }

    func showInteractive(at point: WheelPoint) {
        interactiveAt.append(point)
    }

    func hide() {
        hideCount += 1
    }
}
