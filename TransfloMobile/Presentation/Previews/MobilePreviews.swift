#if DEBUG
import Foundation
import SwiftUI

/// Screens built for Xcode previews, on a throwaway defaults suite and folder.
enum MobilePreviews {
    private static let container = MobileContainer(
        defaults: UserDefaults(suiteName: "TransfloMobilePreviews") ?? .standard,
        documents: FileManager.default.temporaryDirectory.appendingPathComponent("TransfloMobilePreviews")
    )

    static var settings: some View {
        AppLocalizedRoot(localizer: container.localizer) {
            NavigationStack { container.screens.makeSettings() }
        }
    }

    static var home: some View {
        AppLocalizedRoot(localizer: container.localizer) {
            NavigationStack {
                MobileHomeView(viewModel: container.screens.home)
            }
        }
    }

    static var jobs: some View {
        AppLocalizedRoot(localizer: container.localizer) {
            NavigationStack { container.screens.makeJobs() }
        }
    }
}
#endif
