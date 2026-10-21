import Foundation
import Observation
import TransfloDomain

/// Split: media into N equal parts, or a PDF into files of N pages.
@Observable
final class SplitEditorViewModel: ToolEditorModel {
    static let partRange = 2...20

    private(set) var preview: ToolPreview = .empty
    enum Mode: Hashable { case equal, custom }
    var mode = Mode.equal
    var cutTime = 1.0
    private(set) var cuts: [Double] = []
    var parts = 2
    var pagesPerFile = 1

    @ObservationIgnored let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var isPDF: Bool { format?.id.rawValue == "pdf" }

    /// Allowed pages per file: from 1 up to one less than the document.
    var pageRange: ClosedRange<Int> { 1...max(1, (preview.pageCount ?? 2) - 1) }

    var settings: ToolSettings? {
        if isPDF {
            guard let pages = preview.pageCount, pages > 1, pageRange.contains(pagesPerFile) else { return nil }
            return .splitPages(every: pagesPerFile)
        }
        guard let duration = preview.duration, duration.isFinite, duration > 0,
              Self.partRange.contains(parts) else { return nil }
        if mode == .custom { return cuts.isEmpty ? nil : .split(points: cuts) }
        guard duration / Double(parts) > 0.05 else { return nil }
        return .split(points: (1..<parts).map { duration * Double($0) / Double(parts) })
    }

    var canAddCut: Bool {
        guard let duration = preview.duration else { return false }
        return cutTime.isFinite && cutTime > 0.05 && cutTime < duration - 0.05 && cuts.count < 19
            && cuts.allSatisfy { abs($0 - cutTime) >= 0.05 }
    }
    var outputCount: Int {
        if isPDF {
            return ((preview.pageCount ?? 0) + max(1, pagesPerFile) - 1) / max(1, pagesPerFile)
        }
        return mode == .custom ? cuts.count + 1 : parts
    }
    var segmentDurations: [Double] {
        guard case .split(let cuts) = settings, let duration = preview.duration else { return [] }
        let bounds = [0] + cuts + [duration]
        return zip(bounds, bounds.dropFirst()).map { $1 - $0 }
    }

    func addCut() { if canAddCut { cuts.append(cutTime); cuts.sort() } }
    func removeCut(_ time: Double) { cuts.removeAll { $0 == time } }
    func reset() { parts = 2; pagesPerFile = 1; cuts = []; mode = .equal }

    func load() async {
        preview = await previews.preview(of: item, format: format)
    }
}
