import Foundation

/// The private folder a recipe works in, so only its final result appears beside the original.
public protocol RecipeWorkspace: Sendable {
    /// A new empty folder for one file's run.
    func makeFolder() throws(JobError) -> URL
    /// A copy of `source` inside `folder` (a clone on APFS, so it costs no time or space).
    func clone(_ source: URL, into folder: URL) throws(JobError) -> URL
    /// Moves `result` into `folder` under its own name, or a numbered one if that's taken.
    func publish(_ result: URL, into folder: URL) throws(JobError) -> URL
    func remove(_ folder: URL)
}
