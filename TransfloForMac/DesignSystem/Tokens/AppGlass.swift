import SwiftUI

/// Glass surfaces. Liquid Glass on macOS 26 and later; before that, a frosted material with a
/// hairline edge (and the floating shadow for surfaces over the desktop).
enum AppGlass {
    /// Over arbitrary desktop content: the wheel and the job HUD.
    case floating
    /// Grouped content inside a window: settings sections and editor panels.
    case card
}

/// Applies an `AppGlass` surface behind the content, clipped to `shape`.
struct AppGlassModifier<S: InsettableShape>: ViewModifier {
    let glass: AppGlass
    let shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if InterfaceStyle.shared.preferences.solidSurfaces || reduceTransparency {
            content.background(AppColors.surface, in: shape)
                .overlay(shape.strokeBorder(AppColors.divider, lineWidth: AppDimensions.Stroke.hairline))
                .appShadow(glass == .floating ? AppShadows.floating : AppShadows.none)
        } else if #available(macOS 26.0, iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(material, in: shape)
                .overlay(shape.strokeBorder(AppColors.glassEdge, lineWidth: AppDimensions.Stroke.hairline))
                .appShadow(glass == .floating ? AppShadows.floating : AppShadows.none)
        }
    }

    private var material: Material {
        glass == .floating ? .regularMaterial : .thinMaterial
    }
}

extension View {
    /// Puts the content on a glass surface shaped like `shape`.
    func appGlass<S: InsettableShape>(_ glass: AppGlass, in shape: S) -> some View {
        modifier(AppGlassModifier(glass: glass, shape: shape))
    }
}
