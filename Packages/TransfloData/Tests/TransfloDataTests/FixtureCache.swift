import Foundation

/// Generates each fixture format once and hands out copies, so hundreds of parallel matrix cases
/// share one source file per format. In-flight generations are shared too (actors re-enter at `await`).
actor FixtureCache {
    static let shared = FixtureCache()

    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("TransfloFixtureCache-\(UUID().uuidString)", isDirectory: true)
    private var fixtures: [String: Task<URL, any Error>] = [:]

    /// A fresh copy of the `format` fixture inside `destination`, named `source.<ext>`.
    func copy(_ format: String, into destination: URL) async throws -> URL {
        let original = try await fixture(format).value
        let copy = destination.appendingPathComponent(original.lastPathComponent)
        try FileManager.default.copyItem(at: original, to: copy)
        return copy
    }

    private func fixture(_ format: String) -> Task<URL, any Error> {
        if let task = fixtures[format] { return task }
        let home = folder.appendingPathComponent(format, isDirectory: true)
        let task = Task {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            return try await MediaFixtures.make(format, in: home)
        }
        fixtures[format] = task
        return task
    }
}
