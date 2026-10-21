import Foundation

/// Reads the files selected in Finder.
public protocol FinderSelectionReading: Sendable {
    /// Selected items, folders included; empty when nothing is selected.
    /// Throws `.automationDenied` when the user hasn't allowed Transflo to control Finder.
    func selection() async throws(JobError) -> [URL]
}
