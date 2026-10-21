import Foundation
import Observation
import TransfloDomain

/// Per-drop compression: one of three presets for every file type, as on iPhone and iPad. A saved
/// size budget from an earlier version opens as the nearest preset.
@Observable
final class CompressEditorViewModel: ToolEditorModel {
    var level: CompressionLevel = .medium
    private(set) var originalBytes: Int64?
    private(set) var isLoaded = false
    let itemCount: Int
    let fileName: String?
    let isPDF: Bool
    @ObservationIgnored private let items: [URL]
    @ObservationIgnored private let size: (URL) -> Int64?

    init(
        items: [URL],
        formats: [FormatDescriptor?],
        initialGoal: CompressionGoal = .medium,
        size: @escaping (URL) -> Int64? = { url in
            (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        }
    ) {
        self.items = items
        self.size = size
        itemCount = items.count
        fileName = items.count == 1 ? items.first?.lastPathComponent : nil
        isPDF = formats.contains { $0?.id.rawValue == "pdf" }
        if case .level(let value) = CompressionChoice(initialGoal).goal { level = value }
    }

    var settings: ToolSettings? {
        guard isLoaded, !items.isEmpty else { return nil }
        return .compress(.level(level))
    }

    func load() async {
        var total: Int64 = 0
        for item in items {
            guard let bytes = size(item), bytes >= 0 else { isLoaded = true; return }
            let (next, overflow) = total.addingReportingOverflow(bytes)
            guard !overflow else { isLoaded = true; return }
            total = next
        }
        originalBytes = total
        isLoaded = true
    }
}
