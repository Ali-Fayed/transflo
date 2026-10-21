import Foundation
import Observation
import TransfloDomain

@Observable
final class BackgroundRemovalEditorViewModel: ToolEditorModel {
    let item: URL
    private(set) var original: Data?
    private(set) var result: Data?
    private(set) var subjects: [Int] = []
    private(set) var rendering = false
    private(set) var error: L10nKey?
    var options = BackgroundRemovalSettings()
    var showOriginal = false
    var solidBackground = false
    var color = "#F2F5F4"
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding
    @ObservationIgnored private let inspector: (any ToolInspectionProviding)?
    @ObservationIgnored private var rendered: BackgroundRemovalSettings?
    @ObservationIgnored private var revision = 0

    init(
        item: URL,
        format: FormatDescriptor?,
        previews: any ToolPreviewProviding,
        inspector: (any ToolInspectionProviding)?
    ) {
        self.item = item; self.format = format; self.previews = previews; self.inspector = inspector
    }
    var requested: BackgroundRemovalSettings {
        var settings = options
        settings.background = solidBackground ? color : nil
        return settings
    }
    var settings: ToolSettings? {
        guard result != nil, !rendering, rendered == requested else { return nil }
        return .removeBackground(requested)
    }
    func load() async {
        original = await previews.preview(of: item, format: format).thumbnail
        await refresh()
    }
    func refresh() async {
        revision += 1
        let version = revision
        let snapshot = requested
        rendering = true; error = nil
        do {
            guard let inspector else { throw JobError.unsupported }
            let preview = try await inspector.background(of: item, settings: snapshot)
            guard !Task.isCancelled, version == revision else { return }
            result = preview.thumbnail; subjects = preview.subjects; rendered = snapshot
        } catch {
            guard !Task.isCancelled, version == revision else { return }
            result = nil; rendered = nil
            self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed
        }
        if version == revision { rendering = false }
    }
    func reset() { options = BackgroundRemovalSettings(); solidBackground = false; showOriginal = false }
}
