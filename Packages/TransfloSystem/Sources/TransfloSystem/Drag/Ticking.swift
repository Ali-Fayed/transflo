/// Calls a closure repeatedly on the main actor until stopped.
@MainActor
public protocol Ticking: AnyObject {
    func start(_ tick: @escaping @MainActor () -> Void)
    func stop()
}
