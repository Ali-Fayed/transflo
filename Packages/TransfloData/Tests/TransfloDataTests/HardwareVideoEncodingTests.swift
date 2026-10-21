import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Hardware video encoding")
struct HardwareVideoEncodingTests {
    @Test("hardware decoding is requested once before every input")
    func decoding() {
        let arguments = ["-ss", "2", "-i", "a.mp4", "-i", "b.mp4", "-c:v", "h264_videotoolbox", "out.mp4"]
        #expect(FFmpegRunner.hardwareDecoding(arguments) == [
            "-ss", "2", "-hwaccel", "videotoolbox", "-i", "a.mp4", "-hwaccel", "videotoolbox", "-i", "b.mp4",
            "-c:v", "h264_videotoolbox", "out.mp4"
        ])
        let already = ["-hwaccel", "videotoolbox", "-i", "a.mp4", "out.mp4"]
        #expect(FFmpegRunner.hardwareDecoding(already) == already)
        #expect(FFmpegRunner.hardwareDecoding(["out.mp4"]) == ["out.mp4"])
    }

    @Test("both Apple hardware encoders share the session pool")
    func encoders() {
        #expect(FFmpegRunner.hardwareEncoders == ["h264_videotoolbox", "hevc_videotoolbox"])
    }

    @Test("size targets use constant-bitrate hardware H.264 with headroom, and VP9 for WebM")
    func sizeTargets() {
        for format in ["mp4", "mov", "mkv"] {
            let arguments = MediaTargetCompressor.videoEncoding(format: format, bitrate: 2_000_000)
            #expect(arguments.starts(with: ["-c:v", "h264_videotoolbox", "-b:v", "1900000", "-constant_bit_rate", "1"]))
            #expect(MediaTargetCompressor.usesHardwareVideo(format))
        }
        let webm = MediaTargetCompressor.videoEncoding(format: "webm", bitrate: 2_000_000)
        #expect(webm.starts(with: ["-c:v", "libvpx-vp9", "-b:v", "2000000"]))
        #expect(!MediaTargetCompressor.usesHardwareVideo("webm"))
        #expect(!webm.contains("mpeg4"))
    }

    @Test("Smaller file uses HEVC tagged for Apple players; the other levels stay H.264")
    func compressionLevels() throws {
        let smaller = try #require(FFmpegToolArguments.compress("mp4", level: .strong))
        #expect(smaller.starts(with: ["-c:v", "hevc_videotoolbox", "-tag:v", "hvc1"]))
        let mkv = try #require(FFmpegToolArguments.compress("mkv", level: .strong))
        #expect(mkv.starts(with: ["-c:v", "hevc_videotoolbox", "-q:v"]))
        for level in [CompressionLevel.light, .medium] {
            let arguments = try #require(FFmpegToolArguments.compress("mov", level: level))
            #expect(arguments.starts(with: ["-c:v", "h264_videotoolbox"]))
        }
        #expect(FFmpegToolArguments.compress("avi", level: .strong) == nil)
    }
}
