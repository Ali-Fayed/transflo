import Foundation
import Observation
import TransfloDomain

@Observable
final class AssemblyEditorViewModel: ToolEditorModel {
    let items: [URL]
    let isPDFExport: Bool
    private(set) var facts: [ToolPreview] = []
    private(set) var order: [Int]
    var paper = AssemblySettings.Paper.original
    var landscape = false
    var margin = 24.0
    var fill = false
    @ObservationIgnored private let formats: [FormatDescriptor?]
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(items: [URL], formats: [FormatDescriptor?], isPDFExport: Bool, previews: any ToolPreviewProviding) {
        self.items = items; self.formats = formats; self.isPDFExport = isPDFExport; self.previews = previews
        order = Array(items.indices)
    }

    var assembly: AssemblySettings {
        AssemblySettings(order: order, paper: paper, landscape: landscape, margin: margin, fill: fill)
    }
    var settings: ToolSettings? {
        guard facts.count == items.count, assembly.ordered(items) != nil,
              order.allSatisfy({ facts[$0].width != nil || facts[$0].duration != nil || facts[$0].pageCount != nil })
        else { return nil }
        return .assemble(assembly)
    }
    var totalDuration: Double { order.reduce(0) { $0 + (facts.indices.contains($1) ? facts[$1].duration ?? 0 : 0) } }
    var totalPages: Int { order.reduce(0) { $0 + (facts.indices.contains($1) ? facts[$1].pageCount ?? 1 : 0) } }
    var firstFact: ToolPreview { order.first.flatMap { facts.indices.contains($0) ? facts[$0] : nil } ?? .empty }
    var outputExtension: String { order.first.map { items[$0].pathExtension.uppercased() } ?? "" }
    var pageSize: CGSize {
        assembly.pageSize(original: CGSize(width: max(1, firstFact.width ?? 1), height: max(1, firstFact.height ?? 1)))
    }
    func load() async {
        var loaded: [ToolPreview] = []
        for index in items.indices {
            guard !Task.isCancelled else { return }
            loaded.append(await previews.preview(of: items[index], format: formats[index]))
        }
        facts = loaded
    }
    func move(from indices: IndexSet, to destination: Int) {
        let source = indices.filter { order.indices.contains($0) }
        guard !source.isEmpty else { return }
        let moving = source.map { order[$0] }
        let target = min(max(0, destination), order.count)
        for index in source.reversed() { order.remove(at: index) }
        order.insert(contentsOf: moving, at: target - source.filter { $0 < target }.count)
    }
    func shift(_ item: Int, by offset: Int) {
        guard let index = order.firstIndex(of: item) else { return }
        let target = index + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
    }
    func remove(_ item: Int) { order.removeAll { $0 == item } }
    func reverse() { order.reverse() }
    func reset() { order = Array(items.indices); paper = .original; landscape = false; margin = 24; fill = false }
}
