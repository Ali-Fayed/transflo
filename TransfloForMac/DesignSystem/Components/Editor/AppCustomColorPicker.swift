import SwiftUI

/// An opaque RGB color panel shared by editors; the persisted/export value is always #RRGGBB.
struct AppCustomColorPicker: View {
    @Environment(Localizer.self) private var localizer
    @Binding var selection: String

    var body: some View {
        ColorPicker(localizer.string(.settingsCustomColor), selection: color, supportsOpacity: false)
            .accessibilityIdentifier("transflo.editor.customColor")
    }

    private var color: Binding<Color> {
        Binding(get: { AppMarkupPalette.color(selection) }, set: { value in
            guard let hex = AppPlatform.hex(value) else { return }
            selection = "#" + hex
        })
    }
}
