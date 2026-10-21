import Foundation
import Observation
import TransfloDomain

@Observable
final class CodeResultsViewModel: ToolEditorModel {
    private(set) var results: [String] = []
    private(set) var selected: Set<Int> = []
    private(set) var error: L10nKey?
    @ObservationIgnored private let items: [URL]
    @ObservationIgnored private let inspector: (any ToolInspectionProviding)?
    init(items: [URL], inspector: (any ToolInspectionProviding)?) { self.items = items; self.inspector = inspector }
    var settings: ToolSettings? {
        let payloads = results.indices.filter(selected.contains).map { results[$0] }
        return payloads.isEmpty ? nil : .copyCodes(payloads)
    }
    func load() async {
        error = nil
        do {
            guard let inspector else { throw JobError.unsupported }
            results = try await inspector.codes(in: items)
            selected = Set(results.indices)
            if results.isEmpty { error = .errorNothingFound }
        } catch { self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed }
    }
    func toggle(_ index: Int) { if selected.remove(index) == nil { selected.insert(index) } }
    func selectAll() { selected = Set(results.indices) }
    func selectNone() { selected = [] }
    func webURL(_ payload: String) -> URL? {
        guard let url = URL(string: payload), let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), url.host != nil else { return nil }
        return url
    }
}
