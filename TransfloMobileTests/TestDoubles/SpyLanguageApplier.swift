import TransfloDomain
@testable import TransfloMobile

/// Records every language applied.
final class SpyLanguageApplier: LanguageApplying {
    private(set) var applied: [AppLanguage] = []

    func apply(_ language: AppLanguage) {
        applied.append(language)
    }
}
