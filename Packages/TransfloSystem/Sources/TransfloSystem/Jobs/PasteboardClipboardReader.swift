import AppKit
import TransfloDomain

/// The files on the clipboard, or a copied image saved to Downloads as a PNG so the wheel can take it.
@MainActor
public struct PasteboardClipboardReader {
    private let pasteboard: NSPasteboard
    private let folder: () -> URL?
    private let now: () -> Date

    public init(
        pasteboard: NSPasteboard = .general,
        folder: @escaping () -> URL? = {
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.pasteboard = pasteboard
        self.folder = folder
        self.now = now
    }

    /// Copied files first; otherwise a copied image, written as `Clipboard 2026-10-20 at 14.05.09.png`.
    /// Empty when the clipboard holds neither.
    public func files() throws(JobError) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty {
            return urls
        }
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return [] }
        guard let folder = folder() else { throw .destinationUnavailable }
        let url = Self.uniqueURL(in: folder, base: "Clipboard \(Self.stamp.string(from: now()))")
        do { try png.write(to: url, options: .withoutOverwriting) } catch { throw .destinationUnavailable }
        return [url]
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()

    private static func uniqueURL(in folder: URL, base: String) -> URL {
        var url = folder.appendingPathComponent(base).appendingPathExtension("png")
        var attempt = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(attempt)").appendingPathExtension("png")
            attempt += 1
        }
        return url
    }
}
