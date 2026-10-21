import Foundation
import TransfloDomain

// @unchecked: the bundle is guarded by `lock`; engines read suffixes from background threads.
/// Tool output suffixes (`photo (compressed).jpg`) in the interface language.
nonisolated final class LocalizedToolSuffixes: ToolSuffixProviding, LanguageApplying, @unchecked Sendable {
    private let lock = NSLock()
    private let baseBundle: Bundle
    private var bundle: Bundle

    init(language: AppLanguage, baseBundle: Bundle = .main) {
        self.baseBundle = baseBundle
        self.bundle = Self.bundle(for: language, in: baseBundle)
    }

    /// The localized suffix (`L10nKey` cases `suffix.<tool>`).
    func suffix(for tool: ToolKind) -> String {
        let key = "suffix.\(tool.rawValue)"
        return lock.withLock { bundle.localizedString(forKey: key, value: tool.rawValue, table: nil) }
    }

    func apply(_ language: AppLanguage) {
        let localized = Self.bundle(for: language, in: baseBundle)
        lock.withLock { bundle = localized }
    }

    private static func bundle(for language: AppLanguage, in base: Bundle) -> Bundle {
        base.path(forResource: language.code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? base
    }
}
