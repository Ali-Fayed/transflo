import TransfloDomain

/// Switches the running interface to a language.
protocol LanguageApplying: AnyObject {
    func apply(_ language: AppLanguage)
}
