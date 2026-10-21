import SwiftUI

/// The only way feature views render text. Resolves `L10nKey`s through the `Localizer`.
struct AppText: View {
    @Environment(Localizer.self) private var localizer
    private let content: AppTextContent
    private let style: AppTextStyle
    private let color: AppTextColor

    init(_ key: L10nKey, style: AppTextStyle = .body, color: AppTextColor = .primary) {
        self.content = .key(key)
        self.style = style
        self.color = color
    }

    /// Renders a format string key (e.g. `"Version %1$@ (%2$@)"`) with `arguments`.
    init(_ key: L10nKey, arguments: [String], style: AppTextStyle = .body, color: AppTextColor = .primary) {
        self.content = .formatted(key, arguments)
        self.style = style
        self.color = color
    }

    /// Renders data that is not translatable copy (format codes such as "PNG", key glyphs).
    /// Renders prepared content (for models that carry their own text).
    init(_ content: AppTextContent, style: AppTextStyle = .body, color: AppTextColor = .primary) {
        self.content = content
        self.style = style
        self.color = color
    }

    init(verbatim text: String, style: AppTextStyle = .body, color: AppTextColor = .primary) {
        self.content = .verbatim(text)
        self.style = style
        self.color = color
    }

    var body: some View {
        Text(resolved)
            .font(AppFonts.font(for: style))
            .foregroundStyle(color.color)
    }

    private var resolved: String {
        switch content {
        case .key(let key): localizer.string(key)
        case let .formatted(key, arguments): localizer.string(key, arguments: arguments)
        case .verbatim(let text): text
        }
    }
}
