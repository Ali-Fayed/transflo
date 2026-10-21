import SwiftUI

/// The system Paste button: reads the clipboard only when tapped, so iOS shows no paste prompt.
/// Reports the pasted items as staged files.
struct AppPasteButton: View {
    let onPasted: ([URL]) -> Void

    var body: some View {
        PasteButton(payloadType: PastedFile.self) { files in
            let urls = files.map(\.url)
            Task { @MainActor in onPasted(urls) }
        }
        .buttonBorderShape(.capsule)
        .tint(AppColors.accent)
        .labelStyle(.titleAndIcon)
        .accessibilityIdentifier("mobile.paste")
    }
}
