import Foundation

/// AirDrop: hands the files to the system AirDrop sheet.
public struct AirDropAction: FileActionPerforming {
    private let sharer: any FileSharing

    public init(sharer: any FileSharing) {
        self.sharer = sharer
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        try await sharer.share(items)
        return []
    }
}
