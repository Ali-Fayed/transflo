import TransfloDomain

/// Forwards a language change to several appliers (the UI localizer and file-name suffixes).
final class CompositeLanguageApplier: LanguageApplying {
    private let appliers: [any LanguageApplying]

    init(_ appliers: [any LanguageApplying]) {
        self.appliers = appliers
    }

    func apply(_ language: AppLanguage) {
        appliers.forEach { $0.apply(language) }
    }
}
