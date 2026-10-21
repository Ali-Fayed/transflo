import AppIntents
import TransfloDomain

/// An output format, for the Convert Files action.
struct FormatEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.format", defaultValue: "Format")
    )
    static let defaultQuery = FormatQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct FormatQuery: EntityStringQuery {
    @Dependency private var services: TransfloIntentServices

    func entities(for identifiers: [String]) async throws -> [FormatEntity] {
        identifiers.compactMap { id in services.catalog.format(FormatID(id)).map(Self.entity) }
    }

    func entities(matching string: String) async throws -> [FormatEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    /// Formats something can be converted to here, so Siri never offers an output this device can't write.
    func suggestedEntities() async throws -> [FormatEntity] {
        let targets = Set(services.catalog.paths.map(\.target))
        return services.catalog.formats.filter { targets.contains($0.id) }.map(Self.entity)
    }

    private static func entity(_ format: FormatDescriptor) -> FormatEntity {
        FormatEntity(id: format.id.rawValue, name: format.displayName)
    }
}
