import Foundation
import os
import TransfloDomain

/// Loads `catalog.json` shipped inside the TransfloData bundle.
public struct BundledCatalogLoader: ConversionCatalogLoading {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "Catalog"
    )

    private let url: URL?

    public init() {
        url = Bundle.module.url(forResource: "catalog", withExtension: "json")
    }

    /// Loads from an explicit file instead of the bundled resource (tests, overrides).
    init(url: URL?) {
        self.url = url
    }

    public func load() throws(CatalogError) -> ConversionCatalog {
        guard let url, let data = try? Data(contentsOf: url) else { throw .unreadable }
        let dto: CatalogDTO
        do {
            dto = try JSONDecoder().decode(CatalogDTO.self, from: data)
        } catch {
            Self.logger.error("Catalog decode failed: \(String(describing: error), privacy: .public)")
            throw .invalid(reason: "malformed JSON")
        }
        return try CatalogMapper.catalog(from: dto)
    }
}
