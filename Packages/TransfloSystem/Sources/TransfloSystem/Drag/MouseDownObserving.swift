/// Reports primary mouse-button presses anywhere on screen.
@MainActor
public protocol MouseDownObserving: AnyObject {
    func start(_ handler: @escaping @MainActor () -> Void)
    func stop()
}
