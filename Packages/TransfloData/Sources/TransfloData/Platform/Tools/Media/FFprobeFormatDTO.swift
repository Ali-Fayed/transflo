/// The container section of ffprobe's JSON.
struct FFprobeFormatDTO: Decodable {
    let duration: String?
    let tags: [String: String]?

    enum CodingKeys: String, CodingKey {
        case duration, tags
    }
}
