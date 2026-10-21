import Foundation

/// Builds a minimal RAR 4.x archive holding one stored (uncompressed) file, so tests can cover
/// RAR input without a RAR writer. Layout follows the RAR 4 technote: marker, archive header,
/// file header, data, end-of-archive.
enum RARFixture {
    static func archive(fileName: String, contents: Data) -> Data {
        var data = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00])
        data += block(type: 0x73, flags: 0x0000, body: Data(repeating: 0, count: 6))
        let name = Data(fileName.utf8)
        var body = Data()
        body += le32(UInt32(contents.count))       // packed size
        body += le32(UInt32(contents.count))       // unpacked size
        body.append(3)                             // host OS: Unix
        body += le32(crc32(contents))              // file CRC
        body += le32(0x5A21_0000)                  // DOS timestamp (2025-01-01)
        body.append(20)                            // version needed: 2.0
        body.append(0x30)                          // method: store
        body += le16(UInt16(name.count))
        body += le32(0o100644)                     // Unix mode (regular file, rw-r--r--)
        body += name
        data += block(type: 0x74, flags: 0x8000, body: body)
        data += contents
        data += block(type: 0x7B, flags: 0x4000, body: Data())
        return data
    }

    private static func block(type: UInt8, flags: UInt16, body: Data) -> Data {
        var header = Data([type]) + le16(flags) + le16(UInt16(7 + body.count))
        header += body
        return le16(UInt16(crc32(header) & 0xFFFF)) + header
    }

    private static func le16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    private static func le32(_ value: UInt32) -> Data {
        Data((0..<4).map { UInt8((value >> ($0 * 8)) & 0xFF) })
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }
}
