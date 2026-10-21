/// What `AppText` shows: translatable copy, a format string with arguments, or data.
enum AppTextContent: Equatable {
    case key(L10nKey)
    case formatted(L10nKey, [String])
    case verbatim(String)
}
