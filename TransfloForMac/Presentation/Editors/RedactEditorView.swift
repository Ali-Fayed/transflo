import SwiftUI

/// Redact editor: drag black boxes over what should disappear.
struct RedactEditorView: View {
    let model: RedactEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            if model.isPDF {
                PDFMarkupNavigation(page: model.selectedPage, count: model.pageCount,
                                    edited: model.editedPageCount) { index in
                    Task { await model.selectPage(index) }
                }
            }
            AppMarkupBoard(thumbnail: model.preview.thumbnail, aspectRatio: PreviewAspect.ratio(model.preview),
                           redactions: model.allBoxes, onBegin: model.begin, onMove: model.move, onEnd: model.end)
            AppText(.editorMarkCount, arguments: [String(model.boxes.count)],
                    style: .caption, color: .secondary)
            ForEach(Array(model.boxes.indices), id: \.self) { index in
                HStack {
                    AppText(.editorRegion, arguments: [String(index + 1)], style: .caption)
                    Spacer()
                    AppIconButton(symbol: .remove, label: .editorRemove) { model.remove(at: index) }
                }
            }
            MarkupFooter(hint: model.isPDF ? .editorPDFMarkupHint : .editorRedactHint,
                         canUndo: model.canUndo, onUndo: model.undo, onClear: model.clear,
                         canClear: !model.boxes.isEmpty, canRedo: model.canRedo, onRedo: model.redo)
        }
    }
}
