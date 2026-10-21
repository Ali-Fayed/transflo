import PhotosUI
import SwiftUI

/// Picks photos and videos from the library as original files (no library access prompt: the
/// system picker runs outside the app). Reports the files, or a failure when none could load.
struct AppPhotosPickerButton: View {
    @Environment(Localizer.self) private var localizer
    let label: L10nKey
    let onPicked: ([URL]) -> Void
    let onFailure: () -> Void
    var onPresentationChange: (Bool) -> Void = { _ in }
    @Binding var isPresented: Bool
    var showsButton = true
    /// What the library shows: photos for image tools, videos for video tools, or both.
    var filter: PHPickerFilter = .any(of: [.images, .videos])
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        Group {
            if showsButton {
                Button(localizer.string(label)) { isPresented = true }
                    .buttonStyle(.bordered)
            } else { Color.clear.frame(height: 0).accessibilityHidden(true) }
        }
        .photosPicker(isPresented: $isPresented, selection: $selection,
                      matching: filter, preferredItemEncoding: .current)
        .onChange(of: isPresented) { _, shown in onPresentationChange(shown) }
        .buttonStyle(.plain)
        .appFocusRing(Capsule())
        .task(id: selection) {
            guard !selection.isEmpty else { return }
            let items = selection
            var urls: [URL] = []
            for item in items {
                guard !Task.isCancelled else {
                    ItemProviderFileLoader.discard(urls)
                    return
                }
                guard let file = try? await item.loadTransferable(type: PickedMediaFile.self) else {
                    ItemProviderFileLoader.discard(urls)
                    if !Task.isCancelled { onFailure(); selection = [] }
                    return
                }
                urls.append(file.url)
            }
            guard !Task.isCancelled else {
                ItemProviderFileLoader.discard(urls)
                return
            }
            onPicked(urls)
            // Changing this task's identity cancels it. Reset only after every transfer has finished.
            selection = []
        }
    }
}
