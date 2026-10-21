import SwiftUI

/// Shows a finished job's results: images get the Photos or Files sheet, everything else goes
/// straight to the system share sheet.
private struct MobileResultPresentation: ViewModifier {
    @Binding var item: SharedFiles?
    let onDismiss: () -> Void

    private var photos: Binding<SharedFiles?> {
        Binding(get: { item.flatMap { PhotoLibrarySaver.accepts($0.urls) ? $0 : nil } },
                set: { if $0 == nil { item = nil } })
    }

    private var shared: [URL]? {
        item.flatMap { PhotoLibrarySaver.accepts($0.urls) ? nil : $0.urls }
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: photos, onDismiss: onDismiss) { files in MobileResultSheet(files: files) }
            .background(AppActivityPresenter(urls: shared) {
                item = nil
                onDismiss()
            })
    }
}

extension View {
    /// Presents `item`'s results when set, and calls `onDismiss` once they are saved or shared.
    func resultPresentation(_ item: Binding<SharedFiles?>, onDismiss: @escaping () -> Void) -> some View {
        modifier(MobileResultPresentation(item: item, onDismiss: onDismiss))
    }
}
