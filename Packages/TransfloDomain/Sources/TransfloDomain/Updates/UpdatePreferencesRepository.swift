import Foundation

/// Persists the automatic update check: whether it runs, when it last asked and which version
/// the user was already told about.
public protocol UpdatePreferencesRepository: Sendable {
    /// `true` unless the user turned automatic checks off.
    func loadChecksAutomatically() -> Bool
    func saveChecksAutomatically(_ enabled: Bool)
    func loadLastCheck() -> Date?
    func saveLastCheck(_ date: Date)
    func loadNotifiedVersion() -> String?
    func saveNotifiedVersion(_ version: String)
}
