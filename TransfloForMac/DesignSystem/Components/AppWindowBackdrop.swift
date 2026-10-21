import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Honors both Transflo's solid-surface preference and the system's Reduce Transparency.
struct AppWindowBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if InterfaceStyle.shared.preferences.solidSurfaces || reduceTransparency {
            AppColors.background
        } else {
            #if os(macOS)
            FrostedWindowBackdrop()
            #else
            Rectangle().fill(.regularMaterial)
            #endif
        }
    }
}

#if os(macOS)
private struct FrostedWindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif
