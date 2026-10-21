/// Loads the conversion catalog.
public protocol ConversionCatalogLoading: Sendable {
    func load() throws(CatalogError) -> ConversionCatalog
}
