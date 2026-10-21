/// Why the conversion catalog could not be loaded.
public enum CatalogError: Error, Sendable, Equatable {
    /// The catalog resource is missing or unreadable.
    case unreadable
    /// The catalog content is inconsistent; `reason` names the first problem found.
    case invalid(reason: String)
}
