/// Every `from` × `to` pair except a format to itself, all using `engines` in preference order.
struct CatalogConversionRuleDTO: Decodable {
    let from: [String]
    let to: [String]
    let engines: [String]

    enum CodingKeys: String, CodingKey {
        case from, to, engines
    }
}
