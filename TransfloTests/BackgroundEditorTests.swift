import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

struct BackgroundEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.png")
    private let preview = ToolPreview(width: 100, height: 50, duration: nil, pageCount: nil, thumbnail: Data([1]))

    @Test func currentPreviewIsRequiredAndSliderValuesAreClamped() async {
        let renderer = FakeBackgroundPreviewRenderer()
        let model = AddBackgroundEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(preview),
                                                 renderer: renderer, debounce: .zero)
        #expect(model.settings == nil)
        await model.load()
        #expect(model.settings == .addBackground(.plain))
        model.update { $0.padding = 4; $0.corners = -2; $0.shadow = .nan }
        #expect(model.settings == nil)
        await model.waitForPreview()
        #expect(model.style.padding == 0.3 && model.style.corners == 0 && model.style.shadow == 0)
        #expect(model.settings == .addBackground(model.style))
        model.reset()
        await model.waitForPreview()
        #expect(model.style == .plain)
    }

    @Test func missingAndFailedPreviewCannotBeAppliedAndCanRetry() async {
        let renderer = FakeBackgroundPreviewRenderer(failure: .failed)
        let model = AddBackgroundEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(preview),
                                                 renderer: renderer)
        await model.load()
        #expect(model.settings == nil && model.errorKey == .beautifyPreviewFailed && !model.isRendering)
        await renderer.setFailure(nil)
        await model.load()
        #expect(model.settings != nil && model.errorKey == nil)
        let missing = AddBackgroundEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(.empty),
                                                   renderer: renderer)
        await missing.load()
        #expect(missing.settings == nil && missing.errorKey != nil)
    }

    @Test func rapidUpdatesKeepOnlyTheLatestStyleAndCancellationDisablesPendingSettings() async {
        let renderer = FakeBackgroundPreviewRenderer(delay: .milliseconds(10))
        let model = AddBackgroundEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(preview),
                                                 renderer: renderer, debounce: .milliseconds(1))
        await model.load()
        model.update { $0.padding = 0.1 }
        model.update { $0.padding = 0.2 }
        model.update { $0.padding = 0.3 }
        await model.waitForPreview()
        #expect(model.settings == .addBackground(model.style))
        #expect(await renderer.renderedStyles.last?.padding == 0.3)
        model.update { $0.ratio = .square }
        model.cancelPreview()
        await model.waitForPreview()
        #expect(!model.isRendering && model.settings == nil)
    }
    @Test func closingWhileTheSourcePreviewLoadsDoesNotPublishLateSettings() async {
        let provider = FakePreviewProvider(preview, delay: .milliseconds(30))
        let model = AddBackgroundEditorViewModel(item: file, format: nil, previews: provider,
                                                 renderer: FakeBackgroundPreviewRenderer())
        let loading = Task { await model.load() }
        try? await Task.sleep(for: .milliseconds(5))
        model.cancelPreview()
        await loading.value
        #expect(model.settings == nil)
        #expect(model.composedPreview == nil)
        #expect(!model.isRendering)
    }

    @Test func customizationWhileTheSourceLoadsAppliesToTheLoadedPreview() async {
        let provider = FakePreviewProvider(preview, delay: .milliseconds(30))
        let model = AddBackgroundEditorViewModel(item: file, format: nil, previews: provider,
                                                 renderer: FakeBackgroundPreviewRenderer(), debounce: .zero)
        let loading = Task { await model.load() }
        try? await Task.sleep(for: .milliseconds(5))
        model.update { $0.padding = 0.2 }
        await loading.value
        #expect(model.settings == .addBackground(model.style))
        #expect(model.style.padding == 0.2)
    }
}
