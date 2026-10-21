import Foundation
import Observation
import TransfloDomain

@Observable
final class MetadataRemovalEditorViewModel: ToolEditorModel {
    struct Source: Identifiable {
        let id: Int
        let name: String
        let entries: [MetadataEntry]
    }
    private(set) var sources: [Source] = []
    private(set) var error: L10nKey?
    var selected = Set(MetadataCategory.allCases)
    @ObservationIgnored private let items: [URL]
    @ObservationIgnored private let inspector: (any ToolInspectionProviding)?
    init(items: [URL], inspector: (any ToolInspectionProviding)?) { self.items = items; self.inspector = inspector }
    var settings: ToolSettings? {
        guard sources.count == items.count, !sources.isEmpty, !selected.isEmpty, error == nil else { return nil }
        return .removeMetadata(selected)
    }
    var removalCount: Int { sources.flatMap(\.entries).filter { selected.contains($0.category) }.count }
    func load() async {
        sources = []; error = nil
        do {
            guard let inspector else { throw JobError.unsupported }
            for (index, url) in items.enumerated() {
                let entries = try await inspector.metadata(in: url)
                sources.append(Source(id: index, name: url.lastPathComponent, entries: entries))
            }
        } catch { self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed }
    }
    func toggle(_ category: MetadataCategory) {
        if selected.remove(category) == nil { selected.insert(category) }
    }
}
