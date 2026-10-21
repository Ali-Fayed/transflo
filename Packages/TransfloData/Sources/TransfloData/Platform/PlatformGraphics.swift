import CoreGraphics
#if canImport(AppKit)
import AppKit

/// The drawing types the shared engines use: AppKit's on the Mac, UIKit's on iPhone and iPad.
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformBezierPath = NSBezierPath
#else
import UIKit

/// The drawing types the shared engines use: AppKit's on the Mac, UIKit's on iPhone and iPad.
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformBezierPath = UIBezierPath
#endif

/// The few drawing calls whose spelling differs between AppKit and UIKit.
enum PlatformGraphics {
    static func color(_ color: CGColor) -> PlatformColor {
        #if canImport(AppKit)
        NSColor(cgColor: color) ?? .black
        #else
        UIColor(cgColor: color)
        #endif
    }

    static func bold(_ font: PlatformFont) -> PlatformFont {
        #if canImport(AppKit)
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        #else
        UIFont.boldSystemFont(ofSize: font.pointSize)
        #endif
    }

    /// `image` shown at `size` points.
    static func image(_ image: CGImage, size: CGSize) -> PlatformImage {
        #if canImport(AppKit)
        NSImage(cgImage: image, size: size)
        #else
        UIImage(cgImage: image, scale: size.width > 0 ? CGFloat(image.width) / size.width : 1, orientation: .up)
        #endif
    }

    /// An open polyline through `points`.
    static func polyline(_ points: [CGPoint]) -> PlatformBezierPath {
        let path = PlatformBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        #if canImport(AppKit)
        points.dropFirst().forEach { path.line(to: $0) }
        #else
        points.dropFirst().forEach { path.addLine(to: $0) }
        #endif
        return path
    }
}
