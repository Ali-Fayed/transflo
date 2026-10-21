import SwiftUI
import TransfloDomain

struct MobileAboutView: View {
    @Environment(Localizer.self) private var localizer
    let version: AppVersion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 20) {
                    AppAppIcon(size: 76)
                    VStack(alignment: .leading, spacing: 6) {
                        AppText(.appName, style: .title)
                        AppText(.settingsVersion, arguments: [version.marketing, version.build],
                                style: .caption, color: .secondary)
                    }
                }
                .padding(.top, 16)
                VStack(alignment: .leading, spacing: 10) {
                    AppText(.mobileAboutLocal, style: .title)
                    AppText(.mobileAboutLocalDetail, color: .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 0) {
                    destination(.mobileSupport, symbol: "questionmark.circle",
                                address: "https://transfloformac.ali-fayed.com/support")
                    Divider().padding(.leading, 58)
                    destination(.mobilePrivacy, symbol: "hand.raised",
                                address: "https://transfloformac.ali-fayed.com/privacy")
                }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
        }
        .appScreenBackground()
        .mobileNavigationBar(.settingsAboutSection)
        .accessibilityIdentifier("mobile.about")
    }

    @ViewBuilder
    private func destination(_ title: L10nKey, symbol: String, address: String) -> some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                HStack(spacing: 14) {
                    Image(systemName: symbol).font(.title3).foregroundStyle(AppColors.accent).frame(width: 28)
                    Text(localizer.string(title)).font(.body.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(AppColors.textSecondary)
                }
                .padding(18).frame(minHeight: 60).contentShape(Rectangle())
            }
        }
    }
}
