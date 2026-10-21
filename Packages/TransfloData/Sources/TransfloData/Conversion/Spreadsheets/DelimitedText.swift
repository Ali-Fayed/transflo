/// RFC 4180 reading and writing for CSV (comma) and TSV (tab): quoted fields, doubled quotes,
/// and line breaks inside quotes.
enum DelimitedText {
    static func rows(from text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.replacingOccurrences(of: "\u{FEFF}", with: "").makeIterator()
        var pending = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if inQuotes {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty:
                inQuotes = true
            case delimiter:
                row.append(field)
                field = ""
            case "\n", "\r\n", "\r":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    static func text(for rows: [[String]], delimiter: Character) -> String {
        rows.map { row in
            row.map { quoted($0, delimiter: delimiter) }.joined(separator: String(delimiter))
        }.joined(separator: "\r\n") + (rows.isEmpty ? "" : "\r\n")
    }

    private static func quoted(_ field: String, delimiter: Character) -> String {
        let needsQuotes = field.contains(delimiter) || field.contains("\"") || field.contains("\n")
            || field.contains("\r") || field.hasPrefix(" ") || field.hasSuffix(" ")
        guard needsQuotes else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
