import TransfloDomain

/// Shows a short message where the user is looking, for things that aren't jobs.
protocol HintPresenting: AnyObject {
    func showHint(_ message: L10nKey, near point: WheelPoint)
}
