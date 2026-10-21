/// The wording that depends on where updates come from: a GitHub release or the App Store.
struct UpdateChannelText: Equatable {
    let noRelease: L10nKey
    let failed: L10nKey
    let installHint: L10nKey
    let openDownload: L10nKey
    let notificationBody: L10nKey

    /// DMG and Homebrew: download the release, or `brew upgrade`.
    static let gitHub = UpdateChannelText(
        noRelease: .updateNoRelease, failed: .updateFailed, installHint: .updateInstallHint,
        openDownload: .updateOpenRelease, notificationBody: .updateNotificationRelease
    )

    /// The App Store installs the update.
    static let appStore = UpdateChannelText(
        noRelease: .updateStoreNoRelease, failed: .updateStoreFailed, installHint: .updateStoreInstallHint,
        openDownload: .updateOpenStore, notificationBody: .updateNotificationStore
    )
}
