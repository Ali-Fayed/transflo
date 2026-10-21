import SwiftUI

/// The frame every tool editor shares: a title, the editor's content, and Cancel / Apply.
struct AppEditorScaffold<Content: View>: View {
    let title: L10nKey
    let canApply: Bool
    let onCancel: () -> Void
    let onApply: () -> Void
    var actionKey: L10nKey = .editorApply
    var width = AppDimensions.Editor.width
    @ViewBuilder let content: () -> Content
    @State private var contentHeight: CGFloat = 0

    private var contentLimit: CGFloat { max(180, (AppPlatform.visibleScreenSize?.height ?? 800) - 180) }
    /// On the Mac the editor has a fixed width, so its window doesn't size itself to a preview that is
    /// still loading. iPhone and iPad fill their scene up to `width`.
    private var fixedWidth: CGFloat? { AppPlatform.visibleScreenSize.map { min(width, $0.width - 40) } }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
            AppText(title, style: .title)
            ScrollView {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                    .padding(.trailing, AppDimensions.Spacing.xSmall)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(contentHeight > 0 ? contentHeight : 300, contentLimit))
            HStack(spacing: AppDimensions.Spacing.small) {
                Spacer()
                AppButton(key: .editorCancel, variant: .secondary, action: onCancel)
                AppButton(key: actionKey, variant: .primary, isEnabled: canApply, action: onApply)
                    .accessibilityIdentifier("transflo.editor.apply")
            }
        }
        .padding(AppDimensions.Spacing.xLarge)
        .frame(minWidth: fixedWidth, maxWidth: fixedWidth ?? width)
        .background(AppWindowBackdrop().ignoresSafeArea())
    }
}
