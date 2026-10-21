import SwiftUI
import TransfloDomain

/// Wheel geometry preferences live beside wheel visibility, with a stable preview viewport.
struct WheelStyleSettingsView: View {
    let viewModel: CustomizationViewModel
    var body: some View {
        SettingsSection(title: .settingsWheelStyle) {
            SettingsRow(label: .settingsWheelSize) {
                AppSegmentedPicker(key: .settingsWheelSize, selection: binding(\.wheelSize), options: Self.sizes,
                                   width: AppDimensions.Window.settingsControlWidth)
            }
            wheelPreview
            SettingsFootnote(message: .settingsWheelSizeHint)
        }
    }

    private var wheelPreview: some View {
        let scale = viewModel.preferences.wheelSize.scale
        return AppRadialWheel(
            wedges: ["PNG", "JPG", "WEBP", "TIFF", "HEIC", "PDF"].map {
                WheelWedgeContent(id: $0, label: .verbatim($0), symbol: nil)
            },
            geometry: WheelGeometry(wedgeCount: 6, innerRadius: AppDimensions.Wheel.innerRadius * scale,
                                    outerRadius: AppDimensions.Wheel.compactOuterRadius * scale,
                                    isRightToLeft: false),
            highlightedIndex: 0, hubTitle: .wheelConvert, hubGlyph: "⇧"
        )
        .scaleEffect(AppDimensions.CustomizationPreview.scale)
        // scaleEffect changes drawing, not layout. Reserve one stable viewport for every size
        // so the full-size wheel cannot widen the settings card or hosting window.
        .frame(width: AppDimensions.CustomizationPreview.viewport, height: AppDimensions.CustomizationPreview.viewport)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func binding<Value>(_ path: WritableKeyPath<InterfaceCustomization, Value>) -> Binding<Value> {
        Binding(get: { viewModel.preferences[keyPath: path] }, set: { value in
            viewModel.update { $0[keyPath: path] = value }
        })
    }
    private static let sizes: [AppSegmentedPicker<InterfaceCustomization.WheelSize>.Option] = [
        .init(value: .compact, label: .settingsSizeCompact), .init(value: .standard, label: .settingsSizeStandard),
        .init(value: .large, label: .settingsSizeLarge)
    ]
}
