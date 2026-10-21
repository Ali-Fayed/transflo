import TransfloDomain

/// Puts new input preferences into effect right away.
protocol InputPreferencesApplying: AnyObject {
    /// Applies `preferences`. Returns `false` if the system refused the shortcut.
    @discardableResult
    func apply(_ preferences: InputPreferences) -> Bool
}
