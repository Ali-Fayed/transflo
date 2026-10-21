import TransfloDomain

/// Output encoder settings per target format. Only LGPL/BSD encoders are used
/// (no libx264/libx265): H.264 goes through VideoToolbox.
enum FFmpegArguments {
    /// Formats ffmpeg reads in Transflo's catalog.
    static let readableFormats: Set<String> = [
        "jpg", "png", "heic", "tiff", "bmp", "webp", "avif", "gif",
        "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma",
        "mp4", "mov", "mkv", "webm", "avi", "wmv"
    ]

    private static let evenDimensions = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
    private static let h264 = ["-c:v", "h264_videotoolbox", "-q:v", "65", "-pix_fmt", "yuv420p", "-vf", evenDimensions]
    private static let aac = ["-c:a", "aac", "-b:a", "160k"]
    private static let gifPalette =
        "fps=12,scale='min(iw,640)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse"

    /// Encoder arguments for `target`, or `nil` when ffmpeg cannot write it.
    static func output(for target: FormatID) -> [String]? {
        image(target.rawValue) ?? audio(target.rawValue) ?? video(target.rawValue)
    }

    private static func image(_ target: String) -> [String]? {
        let still = ["-frames:v", "1", "-update", "1"]
        switch target {
        case "webp": return still + ["-c:v", "libwebp", "-quality", "85"]
        case "avif": return still + ["-c:v", "libsvtav1", "-pix_fmt", "yuv420p", "-vf", evenDimensions, "-f", "avif"]
        case "png", "tiff", "bmp": return still
        case "jpg": return still + ["-q:v", "2"]
        default: return nil
        }
    }

    private static func audio(_ target: String) -> [String]? {
        let codec: [String]
        switch target {
        case "mp3": codec = ["-c:a", "libmp3lame", "-q:a", "2"]
        case "m4a": codec = ["-c:a", "aac", "-b:a", "192k"]
        case "wav": codec = ["-c:a", "pcm_s16le"]
        case "flac": codec = ["-c:a", "flac"]
        case "ogg": codec = ["-c:a", "libvorbis", "-q:a", "5"]
        case "opus": codec = ["-c:a", "libopus", "-b:a", "128k"]
        case "aiff": codec = ["-c:a", "pcm_s16be"]
        case "wma": codec = ["-c:a", "wmav2", "-b:a", "192k"]
        default: return nil
        }
        return ["-vn"] + codec
    }

    private static func video(_ target: String) -> [String]? {
        switch target {
        case "mp4": h264 + aac + ["-movflags", "+faststart"]
        case "mov", "mkv": h264 + aac
        case "webm":
            ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-row-mt", "1", "-c:a", "libopus", "-b:a", "128k"]
        case "avi": ["-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame", "-q:a", "4"]
        case "wmv": ["-c:v", "wmv2", "-q:v", "4", "-c:a", "wmav2", "-b:a", "160k"]
        case "gif": ["-an", "-vf", gifPalette, "-loop", "0"]
        default: nil
        }
    }
}
