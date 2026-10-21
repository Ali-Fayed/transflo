/// One format entry in `catalog.json`.
struct CatalogFormatDTO: Decodable {
    let id: String
    let name: String
    let extensions: [String]
    let family: String

    enum CodingKeys: String, CodingKey {
        case id, name, extensions, family
    }
}
