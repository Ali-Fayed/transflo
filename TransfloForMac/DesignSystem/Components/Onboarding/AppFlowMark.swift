import SwiftUI
import TransfloDomain

/// A living version of the wheel emblem. Its ink is the user's accent, including custom colors.
struct AppFlowMark: View {
    let size: CGFloat
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var settled: Bool {
        revealed || !animated || reduceMotion || InterfaceStyle.shared.preferences.reduceMotion
    }

    var body: some View {
        ZStack {
            Circle().fill(AppColors.accent.opacity(0.06))
            ForEach(0..<6, id: \.self) { index in
                WheelPetalShape(centerAngle: Double(index) * 60, span: 60,
                                innerRadius: size * 0.22, outerRadius: size * 0.46,
                                gap: size * 0.025, cornerRadius: size * 0.06)
                    .fill(index == 1 ? AppColors.accent : AppColors.accent.opacity(0.12))
                    .rotationEffect(.degrees(settled ? 0 : -50))
                    .scaleEffect(settled ? 1 : 0.78)
                    .opacity(settled ? 1 : 0)
            }
            AppIcon(symbol: .flowFile, size: size * 0.19)
                .foregroundStyle(AppColors.accent)
                .scaleEffect(settled ? 1 : 0.7)
        }
        .frame(width: size, height: size)
        .animation(AppAnimations.standard, value: InterfaceStyle.shared.preferences.accentHex)
        .onAppear { withAnimation(AppAnimations.brandReveal) { revealed = true } }
        .accessibilityHidden(true)
    }
}
