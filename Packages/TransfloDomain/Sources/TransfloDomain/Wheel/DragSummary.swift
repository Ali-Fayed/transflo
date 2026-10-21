/// Facts about one selection. A folder, unreadable item or overflow makes its size unknown.
public struct DragSummary: Equatable, Sendable {
    public let itemCount: Int
    public let totalBytes: Int64?

    public init(itemCount: Int, totalBytes: Int64?) {
        self.itemCount = max(0, itemCount)
        self.totalBytes = totalBytes.flatMap { $0 >= 0 ? $0 : nil }
    }
}
