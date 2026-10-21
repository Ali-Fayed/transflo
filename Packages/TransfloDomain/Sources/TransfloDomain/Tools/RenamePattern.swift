/// Expands rename patterns: `{name}` → original base name, `{n}` → counter (zero-padded to the
/// width of the largest number).
public enum RenamePattern {
    public static let nameToken = "{name}"
    public static let numberToken = "{n}"

    public static func names(_ pattern: String, originals: [String], start: Int) -> [String] {
        let width = String(start + max(originals.count - 1, 0)).count
        return originals.enumerated().map { index, original in
            let number = String(start + index)
            let padded = String(repeating: "0", count: max(0, width - number.count)) + number
            let name = pattern.replacingOccurrences(of: nameToken, with: original)
                .replacingOccurrences(of: numberToken, with: padded)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            return name.trimmingCharacters(in: .whitespaces).isEmpty ? original : name
        }
    }
}
