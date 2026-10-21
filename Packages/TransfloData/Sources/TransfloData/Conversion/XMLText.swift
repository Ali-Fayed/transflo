/// Escapes text for XML element content and attribute values.
enum XMLText {
    static func escape(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        // XML 1.0 forbids most control characters even when escaped.
        escaped.unicodeScalars.removeAll { $0.value < 0x20 && ![0x09, 0x0A, 0x0D].contains($0.value) }
        return escaped
    }
}
