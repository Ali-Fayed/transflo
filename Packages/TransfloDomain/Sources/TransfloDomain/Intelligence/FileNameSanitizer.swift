import Foundation

/// Keeps suggested names safe and tidy: lowercase words joined by hyphens, no path separators or
/// leading dots, at most 60 characters. Letters of any script are kept.
public enum FileNameSanitizer {
    public static let maximumLength = 60

    public static func sanitize(_ suggestion: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let words = suggestion.lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
        var name = ""
        for word in words {
            let candidate = name.isEmpty ? word : name + "-" + word
            guard candidate.count <= maximumLength else { break }
            name = candidate
        }
        return name
    }
}
