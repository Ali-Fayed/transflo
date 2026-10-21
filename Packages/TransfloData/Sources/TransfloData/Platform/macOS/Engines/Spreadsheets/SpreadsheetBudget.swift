#if os(macOS)
import TransfloDomain

/// Bounds the expanded in-memory grid, including sparse padding. Never truncates content.
enum SpreadsheetBudget {
    static let rows = 100_000
    static let columns = 16_384
    static let cells = 1_000_000

    static func check(rows rowCount: Int, columns width: Int, cells total: Int) throws(JobError) {
        guard rowCount >= 0, rowCount <= rows, width >= 0, width <= columns, total <= cells else {
            throw .unsupported
        }
    }
}
#endif
