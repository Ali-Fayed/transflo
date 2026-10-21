import Foundation
import TransfloDomain

/// Loads `tools.json` shipped inside the TransfloData bundle.
public struct BundledToolCatalogLoader: ToolCatalogLoading {
    private let url: URL?

    public init() {
        url = Bundle.module.url(forResource: "tools", withExtension: "json")
    }

    init(url: URL?) {
        self.url = url
    }

    public func load() throws(CatalogError) -> ToolCatalog {
        guard let url, let data = try? Data(contentsOf: url) else { throw .unreadable }
        guard let dto = try? JSONDecoder().decode(ToolCatalogDTO.self, from: data) else {
            throw .invalid(reason: "malformed JSON")
        }
        return try ToolCatalogMapper.catalog(from: dto)
    }
}
