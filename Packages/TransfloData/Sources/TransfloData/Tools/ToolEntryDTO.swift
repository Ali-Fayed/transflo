/// One tool in `tools.json`.
struct ToolEntryDTO: Decodable {
    let kind: String
    let families: [String]
    let formats: [String]
    let anyFile: Bool?
    let multiple: Bool?
    let interactive: Bool?

    enum CodingKeys: String, CodingKey {
        case kind, families, formats, anyFile, multiple, interactive
    }
}
