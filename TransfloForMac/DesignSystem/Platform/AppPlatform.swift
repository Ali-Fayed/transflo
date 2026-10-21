import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The few design-system values that come from AppKit on the Mac and UIKit on iPhone and iPad,
/// so components stay one implementation for both apps.
enum AppPlatform {
    /// Whether the system asks for reduced motion.
    static var systemReducesMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// A page's paper in previews of exported documents (white, or dark in Dark Mode).
    static var paper: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    /// The visible screen area a window may use, or `nil` where the window fills its scene.
    static var visibleScreenSize: CGSize? {
        #if os(macOS)
        NSScreen.main?.visibleFrame.size
        #else
        nil
        #endif
    }

    /// Encoded image data (PNG, JPEG, HEIC…) as a SwiftUI image.
    static func image(data: Data) -> Image? {
        #if os(macOS)
        NSImage(data: data).map(Image.init(nsImage:))
        #else
        UIImage(data: data).map(Image.init(uiImage:))
        #endif
    }

    /// The running app's icon.
    static var appIcon: Image {
        #if os(macOS)
        Image(nsImage: NSApp.applicationIconImage)
        #else
        Image(.appIconArtwork)
        #endif
    }

    /// Corner radius over size for drawing the app icon: the Mac artwork carries its own tile, while
    /// iOS icons are square artwork the system rounds (this matches its mask).
    static var appIconCornerFraction: CGFloat {
        #if os(macOS)
        0
        #else
        0.2237
        #endif
    }

    /// What a finished job's results button does: Show in Finder on the Mac, Share on iPhone and iPad.
    static var revealLabel: L10nKey {
        #if os(macOS)
        .jobReveal
        #else
        .jobShare
        #endif
    }

    /// How to place text in the annotate editor: click on the Mac, tap on iPhone and iPad.
    static var annotateHint: L10nKey {
        #if os(macOS)
        .editorAnnotateHint
        #else
        .mobileAnnotateHint
        #endif
    }

    static var revealSymbol: AppSymbol {
        #if os(macOS)
        .revealJob
        #else
        .shareJob
        #endif
    }

    /// The system's icon for a file.
    static func fileIcon(for url: URL) -> Image {
        #if os(macOS)
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        #else
        UIDocumentInteractionController(url: url).icons.last.map(Image.init(uiImage:)) ?? Image(systemName: "doc")
        #endif
    }

    /// `color` as `RRGGBB` in sRGB, or `nil` when it has no RGB form.
    static func hex(_ color: Color) -> String? {
        #if os(macOS)
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
        let components = [red, green, blue]
        #endif
        let channels = components.map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}
