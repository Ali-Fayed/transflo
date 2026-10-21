import SwiftUI

/// Annotate editor: draw on the preview, pick the mark, color and thickness.
struct AnnotateEditorView: View {
    @Bindable var model: AnnotateEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            if model.isPDF {
                PDFMarkupNavigation(page: model.selectedPage, count: model.pageCount,
                                    edited: model.editedPageCount) { index in
                    Task { await model.selectPage(index) }
                }
            }
            AppMarkupBoard(thumbnail: model.preview.thumbnail, aspectRatio: PreviewAspect.ratio(model.preview),
                           annotations: model.marks, onBegin: model.begin, onMove: model.move, onEnd: model.end)
            AppChipGroup(key: .editorMarkupTool, selection: $model.tool, options: Self.tools)
            if model.tool == .text {
                AppTextField(label: .editorTextContent, text: $model.text)
            }
            AppText(.editorColor, style: .headline)
            AppColorSwatches(selection: $model.color)
            AppCustomColorPicker(selection: $model.color)
            AppText(.editorWeight, style: .headline)
            AppChipGroup(key: .editorWeight, selection: $model.weight, options: Self.weights)
            AppText(.editorMarkCount, arguments: [String(model.annotations.count)],
                    style: .caption, color: .secondary)
            MarkupFooter(hint: model.isPDF ? .editorPDFMarkupHint : AppPlatform.annotateHint,
                         canUndo: model.canUndo, onUndo: model.undo, onClear: model.clear,
                         canClear: !model.annotations.isEmpty, canRedo: model.canRedo, onRedo: model.redo)
        }
    }

    private static let tools: [AppSegmentedPicker<MarkupTool>.Option] = [
        .init(value: .box, label: .markupBox), .init(value: .arrow, label: .markupArrow),
        .init(value: .pen, label: .markupPen), .init(value: .text, label: .markupText)
    ]

    private static let weights: [AppSegmentedPicker<MarkupWeight>.Option] = [
        .init(value: .thin, label: .weightThin), .init(value: .medium, label: .weightMedium),
        .init(value: .thick, label: .weightThick)
    ]
}
