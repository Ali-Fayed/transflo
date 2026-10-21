/// Wire shape of `catalog.json`. Conversions are compact rules expanded by `CatalogMapper`.
struct CatalogDTO: Decodable {
    let version: Int
    let formats: [CatalogFormatDTO]
    let conversions: [CatalogConversionRuleDTO]

    enum CodingKeys: String, CodingKey {
        case version, formats, conversions
    }
}
