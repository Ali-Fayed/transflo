public struct CollageSettings: Sendable, Hashable {
    public var order: [Int]
    public var columns: Int
    public var spacing: Int
    public var background: String
    public var cellWidth: Int
    public var cellHeight: Int
    public var fill: Bool
    public init(
        order: [Int],
        columns: Int,
        spacing: Int,
        background: String,
        cellWidth: Int = 640,
        cellHeight: Int = 480,
        fill: Bool = false
    ) {
        self.order = order; self.columns = columns; self.spacing = spacing; self.background = background
        self.cellWidth = cellWidth; self.cellHeight = cellHeight; self.fill = fill
    }
    public var isValid: Bool {
        order.count >= 2 && (1...order.count).contains(columns) && (0...200).contains(spacing)
            && (1...4096).contains(cellWidth) && (1...4096).contains(cellHeight)
            && Set(order).count == order.count
    }
    public var outputWidth: Int { columns * cellWidth + (columns + 1) * spacing }
    public var outputHeight: Int {
        let rows = (order.count + max(1, columns) - 1) / max(1, columns)
        return rows * cellHeight + (rows + 1) * spacing
    }
}
