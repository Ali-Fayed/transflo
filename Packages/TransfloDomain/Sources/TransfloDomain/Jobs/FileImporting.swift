import Foundation

/// Brings files from other apps into a place Transflo may read and write beside (iPhone and iPad,
/// where picked and dropped files are only lent to the app).
public protocol FileImporting: Sendable {
    /// Copies `urls` into a new folder of their own and returns the copies, in order.
    func importFiles(_ urls: [URL]) throws(JobError) -> [URL]
}
