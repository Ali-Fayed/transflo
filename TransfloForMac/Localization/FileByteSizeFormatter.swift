import Foundation

/// Foundation's locale-aware equivalent of ByteCountFormatter with file units.
struct FileByteSizeFormatter: ByteSizeFormatting {
    func string(bytes: Int64, locale: Locale) -> String {
        let locale = locale.language.languageCode?.identifier == "ar"
            ? Locale(identifier: "ar@numbers=arab") : locale
        return ByteCountFormatStyle(style: .file, spellsOutZero: false, locale: locale).format(max(0, bytes))
    }
}
