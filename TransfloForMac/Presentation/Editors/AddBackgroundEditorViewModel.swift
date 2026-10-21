import Foundation
import Observation
import os
import TransfloDomain

/// Coordinates the preview rendering Strategy; settings become applicable only for the current render.
@Observable
final class AddBackgroundEditorViewModel: ToolEditorModel {
    private static let logger = Logger(subsystem: "com.transflo.app", category: "BackgroundPreview")
    private(set) var preview: ToolPreview = .empty
    private(set) var composedPreview: Data?
    private(set) var style: BackgroundStyle
    private(set) var isRendering = false
    private(set) var errorKey: L10nKey?

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding
    @ObservationIgnored private let renderer: (any BackgroundPreviewRendering)?
    @ObservationIgnored private let initialStyle: BackgroundStyle
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var renderedStyle: BackgroundStyle?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var loadGeneration = 0

    init(
        item: URL,
        format: FormatDescriptor?,
        previews: any ToolPreviewProviding,
        renderer: (any BackgroundPreviewRendering)? = nil,
        initialStyle: BackgroundStyle = .plain,
        debounce: Duration = .milliseconds(60)
    ) {
        self.item = item
        self.format = format
        self.previews = previews
        self.renderer = renderer
        self.initialStyle = initialStyle.validated
        self.style = initialStyle.validated
        self.debounce = debounce
    }

    /// The legacy solid-color binding, also used by the shared swatch component.
    var color: String {
        get { if case .solid(let hex) = style.fill { hex } else { "" } }
        set { update { $0.fill = .solid(newValue) } }
    }

    var settings: ToolSettings? {
        guard preview.thumbnail != nil, composedPreview != nil, renderedStyle == style else { return nil }
        return .addBackground(style)
    }

    var canvasAspectRatio: Double {
        let size = style.canvasDimensions(imageWidth: preview.width ?? 1, imageHeight: preview.height ?? 1)
        return size.height > 0 ? size.width / size.height : 1
    }

    func load() async {
        renderTask?.cancel()
        revision += 1
        loadGeneration += 1
        let generation = loadGeneration
        isRendering = false
        composedPreview = nil
        renderedStyle = nil
        errorKey = nil
        let loaded = await previews.preview(of: item, format: format)
        guard !Task.isCancelled, generation == loadGeneration else { return }
        preview = loaded
        guard let bytes = loaded.thumbnail, !bytes.isEmpty else {
            errorKey = .beautifyPreviewFailed
            return
        }
        await render(bytes, snapshot: style, revision: revision)
    }

    func update(_ edit: (inout BackgroundStyle) -> Void) {
        var next = style
        edit(&next)
        next = next.validated
        guard next != style else { return }
        style = next
        errorKey = nil
        revision += 1
        renderTask?.cancel()
        guard let bytes = preview.thumbnail else { return }
        // Without a renderer, the existing solid-fill preview path remains usable by legacy callers.
        guard renderer != nil else {
            composedPreview = bytes
            renderedStyle = style
            return
        }
        isRendering = true
        let snapshot = style
        let revision = revision
        renderTask = Task { [weak self, debounce] in
            do { try await Task.sleep(for: debounce) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.render(bytes, snapshot: snapshot, revision: revision)
        }
    }

    var composition: Int {
        if style.padding == 0.05 && style.corners == 0.02 && style.shadow == 10 { return 0 }
        if style.padding == 0.12 && style.corners == 0.04 && style.shadow == 35 { return 1 }
        if style.padding == 0.22 && style.corners == 0.06 && style.shadow == 50 { return 2 }
        return -1
    }
    func applyComposition(_ preset: Int) {
        update {
            switch preset {
            case 0: $0.padding = 0.05; $0.corners = 0.02; $0.shadow = 10
            case 2: $0.padding = 0.22; $0.corners = 0.06; $0.shadow = 50
            default: $0.padding = 0.12; $0.corners = 0.04; $0.shadow = 35
            }
        }
    }

    func reset() { update { $0 = initialStyle } }

    func cancelPreview() {
        renderTask?.cancel()
        renderTask = nil
        revision += 1
        loadGeneration += 1
        isRendering = false
    }

    /// Waits for the current debounced preview (test harness and explicit completion synchronization).
    func waitForPreview() async { await renderTask?.value }

    private func render(_ bytes: Data, snapshot: BackgroundStyle, revision: Int) async {
        isRendering = true
        defer { if revision == self.revision { isRendering = false } }
        do {
            let result: Data
            if let renderer { result = try await renderer.render(bytes, style: snapshot) } else { result = bytes }
            guard !Task.isCancelled, revision == self.revision else { return }
            guard !result.isEmpty else { throw JobError.failed }
            composedPreview = result
            renderedStyle = snapshot
            errorKey = nil
            isRendering = false
        } catch {
            guard !Task.isCancelled, revision == self.revision else { return }
            Self.logger.error("Preview render failed: \(String(describing: error), privacy: .private)")
            composedPreview = nil
            renderedStyle = nil
            errorKey = .beautifyPreviewFailed
            isRendering = false
        }
    }
}
