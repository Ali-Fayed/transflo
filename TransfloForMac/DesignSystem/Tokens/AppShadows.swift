import SwiftUI

/// Elevation for surfaces that float over arbitrary desktop content.
enum AppShadows {
    struct Spec {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    /// The radial wheel: soft and close, enough to separate it from any wallpaper.
    static let floating = Spec(color: .black.opacity(0.22), radius: 10, y: 3)
    /// A wheel petal sitting slightly above the disc.
    static let petal = Spec(color: .black.opacity(0.10), radius: 3, y: 1.5)
    /// The hub pill, floating a little higher than the petals.
    static let pill = Spec(color: .black.opacity(0.14), radius: 7, y: 2)
    /// No elevation.
    static let none = Spec(color: .clear, radius: 0, y: 0)
}

extension View {
    /// Applies a shadow token.
    func appShadow(_ spec: AppShadows.Spec) -> some View {
        shadow(color: spec.color, radius: spec.radius, y: spec.y)
    }
}
