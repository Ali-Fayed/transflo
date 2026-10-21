import Foundation
import TransfloDomain

/// Reads a text file as UTF-8 (with or without BOM), UTF-16 (with BOM), or Windows-1252 as a last resort.
enum TextFileReader {
    static func read(_ url: URL) throws(JobError) -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw .failed }
        guard size <= 64 * 1024 * 1024 else { throw .unsupported }
        guard let data = try? Data(contentsOf: url) else { throw .failed }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf16) { return text }
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        throw .failed
    }

    static func write(_ text: String, to url: URL) throws(JobError) {
        try OutputFile.write(to: url) { staged throws(JobError) in
            do { try Data(text.utf8).write(to: staged) } catch { throw .failed }
        }
    }
}
