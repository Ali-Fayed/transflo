import Foundation
import TransfloDomain

/// Strategy: reads metadata only, never enumerates directory contents.
public struct FileDragSummaryProvider: DragSummaryProviding {
    public init() {}

    public func summary(for items: [URL]) -> DragSummary {
        var total: Int64 = 0
        for item in items {
            guard item.isFileURL,
                  let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true, let size = values.fileSize, size >= 0 else {
                return DragSummary(itemCount: items.count, totalBytes: nil)
            }
            let sum = total.addingReportingOverflow(Int64(size))
            guard !sum.overflow else { return DragSummary(itemCount: items.count, totalBytes: nil) }
            total = sum.partialValue
        }
        return DragSummary(itemCount: items.count, totalBytes: total)
    }
}
