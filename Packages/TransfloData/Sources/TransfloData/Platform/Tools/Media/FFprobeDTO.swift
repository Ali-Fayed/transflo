/// Wire shape of `ffprobe -print_format json -show_streams -show_format`.
struct FFprobeDTO: Decodable {
    let streams: [FFprobeStreamDTO]?
    let format: FFprobeFormatDTO?

    enum CodingKeys: String, CodingKey {
        case streams, format
    }
}
