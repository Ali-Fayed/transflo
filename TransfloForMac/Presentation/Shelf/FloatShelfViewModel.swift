import Foundation
import Observation

/// The floating shelf's contents: files in the order they arrived, each once.
@Observable
final class FloatShelfViewModel {
    private(set) var items: [URL] = []
    private(set) var isCollapsed = false

    var isEmpty: Bool { items.isEmpty }

    /// Appends files not already on the shelf and expands it.
    func add(_ urls: [URL]) {
        var paths = Set(items.map(\.standardizedFileURL.path))
        for url in urls where paths.insert(url.standardizedFileURL.path).inserted {
            items.append(url)
        }
        isCollapsed = false
    }

    func remove(_ url: URL) {
        items.removeAll { $0.standardizedFileURL.path == url.standardizedFileURL.path }
    }

    func clear() {
        items.removeAll()
        isCollapsed = false
    }

    func toggleCollapsed() {
        isCollapsed.toggle()
    }
}
