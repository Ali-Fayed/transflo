/// Loads the tool catalog.
public protocol ToolCatalogLoading: Sendable {
    func load() throws(CatalogError) -> ToolCatalog
}
