/// Problems the Settings screen reports inline.
enum SettingsErrorState: Equatable {
    case launchAtLoginRequiresApproval
    case launchAtLoginFailed

    /// The message shown under the affected row.
    var messageKey: L10nKey {
        switch self {
        case .launchAtLoginRequiresApproval: .launchAtLoginRequiresApproval
        case .launchAtLoginFailed: .launchAtLoginFailed
        }
    }
}
