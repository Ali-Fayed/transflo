import Foundation
import Observation
import SwiftUI
import TransfloDomain

/// Resolves `L10nKey`s in the language chosen in Settings, independent of the system language.
///
/// It loads the matching `.lproj` bundle at runtime, so a language switch applies immediately
/// without relaunching. Observation tracks `bundle`, so views that read strings re-render.
@Observable
final class Localizer: LanguageApplying, LayoutDirectionProviding {
    private(set) var language: AppLanguage
    private var bundle: Bundle
    @ObservationIgnored private let baseBundle: Bundle

    init(language: AppLanguage, baseBundle: Bundle = .main) {
        self.language = language
        self.baseBundle = baseBundle
        self.bundle = Self.bundle(for: language, in: baseBundle)
    }

    var isRightToLeft: Bool {
        language.isRightToLeft
    }

    var layoutDirection: LayoutDirection {
        language.isRightToLeft ? .rightToLeft : .leftToRight
    }

    var locale: Locale {
        Locale(identifier: language.code)
    }

    /// The translation of `key`, or the key itself when the translation is missing.
    func string(_ key: L10nKey) -> String {
        bundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
    }

    /// The translation of a format-string `key` filled with `arguments`.
    func string(_ content: AppTextContent) -> String {
        switch content {
        case .key(let key): string(key)
        case let .formatted(key, arguments): string(key, arguments: arguments)
        case .verbatim(let text): text
        }
    }

    func string(_ key: L10nKey, arguments: [String]) -> String {
        String(format: string(key), locale: locale, arguments: arguments.map { $0 as CVarArg })
    }

    func apply(_ language: AppLanguage) {
        guard language != self.language else { return }
        self.language = language
        bundle = Self.bundle(for: language, in: baseBundle)
    }

    private static func bundle(for language: AppLanguage, in base: Bundle) -> Bundle {
        guard let path = base.path(forResource: language.code, ofType: "lproj"),
              let localized = Bundle(path: path) else {
            return base
        }
        return localized
    }
}
