/// Wire shape of `tools.json`.
struct ToolCatalogDTO: Decodable {
    let version: Int
    let tools: [ToolEntryDTO]

    enum CodingKeys: String, CodingKey {
        case version, tools
    }
}
