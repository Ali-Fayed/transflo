/// One stream in ffprobe's JSON.
struct FFprobeStreamDTO: Decodable {
    let codecType: String?
    let width: Int?
    let height: Int?
    let channels: Int?
    let averageFrameRate: String?
    let sideData: [SideData]?
    let tags: [String: String]?

    struct SideData: Decodable {
        let rotation: Double?
    }

    var swapsDimensions: Bool {
        let rotation = sideData?.compactMap(\.rotation).first ?? tags?["rotate"].flatMap(Double.init) ?? 0
        guard rotation.isFinite else { return false }
        return abs(rotation.truncatingRemainder(dividingBy: 180)) == 90
    }

    enum CodingKeys: String, CodingKey {
        case codecType = "codec_type"
        case width, height, channels
        case averageFrameRate = "avg_frame_rate"
        case sideData = "side_data_list"
        case tags
    }
}
