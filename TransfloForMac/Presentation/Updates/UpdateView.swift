import SwiftUI

struct UpdateView: View {
    let viewModel: UpdateViewModel
    let openDownload: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
            AppText(.menuCheckUpdates, style: .headline)
            HStack {
                if viewModel.isChecking { AppSpinner() }
                AppText(viewModel.message, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("updates.message")
            }
            AppText(.updateInstalledVersion, arguments: [viewModel.currentVersion], color: .secondary)
            if let version = viewModel.availableVersion {
                AppText(.updateLatestVersion, arguments: [version])
                AppText(viewModel.text.installHint, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                AppButton(key: .updateClose, action: dismiss)
                Spacer()
                if viewModel.availableVersion != nil {
                    AppButton(key: viewModel.text.openDownload, variant: .primary, action: openDownload)
                } else {
                    AppButton(key: .updateRetry, variant: .primary, isEnabled: !viewModel.isChecking) {
                        Task { await viewModel.check() }
                    }
                }
            }
        }
        .padding(AppDimensions.Window.welcomePadding)
        .frame(width: AppDimensions.Window.welcomeWidth)
        .background(AppWindowBackdrop().ignoresSafeArea())
    }
}
