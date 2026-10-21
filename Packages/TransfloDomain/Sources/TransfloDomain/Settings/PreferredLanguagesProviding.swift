/// Supplies the user's system language preferences, most preferred first.
public protocol PreferredLanguagesProviding: Sendable {
    /// BCP-47 codes such as `"ar-EG"` or `"en"`, in preference order.
    var preferredLanguageCodes: [String] { get }
}
