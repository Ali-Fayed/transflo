/// Compares the three-part release versions both update sources publish.
enum ReleaseVersion {
    /// Whether `latest` is newer than `current`; `nil` when either isn't a stable `major.minor.patch`.
    static func isNewer(_ latest: String, than current: String) -> Bool? {
        guard let latest = components(latest), let current = components(current) else { return nil }
        return current.lexicographicallyPrecedes(latest)
    }

    /// Accepts an optional `v` prefix; rejects malformed or prerelease versions.
    static func components(_ value: String) -> [UInt]? {
        let normalized = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let numbers = parts.compactMap { UInt($0) }
        return numbers.count == 3 ? numbers : nil
    }
}
