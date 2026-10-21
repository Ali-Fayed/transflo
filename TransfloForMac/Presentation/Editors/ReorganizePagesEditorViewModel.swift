import Foundation
import Observation
import TransfloDomain

/// Reorganize pages: drag pages into a new order and drop the ones you don't want.
@Observable
final class ReorganizePagesEditorViewModel: ToolEditorModel {
    private(set) var thumbnails: [Data] = []
    /// Zero-based page indices in their new order.
    private(set) var order: [Int] = []

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, previews: any ToolPreviewProviding) {
        self.item = item
        self.previews = previews
    }

    var pageCount: Int { thumbnails.count }

    var settings: ToolSettings? {
        guard pageCount > 0, !order.isEmpty, order != Array(0..<pageCount) else { return nil }
        return .pages(order)
    }

    func load() async {
        thumbnails = await previews.pageThumbnails(of: item)
        order = Array(0..<pageCount)
    }

    func thumbnail(ofPage page: Int) -> Data? {
        thumbnails.indices.contains(page) ? thumbnails[page] : nil
    }

    /// Moves the rows at `offsets` to before `destination`, as a list drag reports it.
    func move(from offsets: IndexSet, to destination: Int) {
        let safe = offsets.filter { order.indices.contains($0) }
        let destination = min(max(destination, 0), order.count)
        let moving = safe.sorted().map { order[$0] }
        var remaining = order.indices.filter { !safe.contains($0) }.map { order[$0] }
        remaining.insert(contentsOf: moving, at: destination - safe.filter { $0 < destination }.count)
        order = remaining
    }

    /// Drops a page; the last remaining page stays.
    func remove(page: Int) {
        guard order.count > 1 else { return }
        order.removeAll { $0 == page }
    }

    func reverse() { order.reverse() }
    func movePage(_ page: Int, by delta: Int) {
        guard let index = order.firstIndex(of: page), order.indices.contains(index + delta) else { return }
        order.swapAt(index, index + delta)
    }

    func reset() {
        order = Array(0..<pageCount)
    }
}
