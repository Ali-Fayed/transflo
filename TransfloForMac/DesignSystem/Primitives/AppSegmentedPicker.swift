import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Localized choices: fixed-width AppKit segments on Mac, accent-aware touch controls on mobile.
struct AppSegmentedPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: L10nKey
        var id: Value { value }
    }

    @Environment(Localizer.self) private var localizer
    @Environment(\.layoutDirection) private var direction
    @Environment(\.isEnabled) private var isEnabled
    let key: L10nKey
    @Binding var selection: Value
    let options: [Option]
    var width: CGFloat?

    var body: some View {
        #if os(macOS)
        NativeControl(label: localizer.string(key), selection: $selection, isEnabled: isEnabled,
                      options: direction == .rightToLeft ? options.reversed() : options,
                      labels: (direction == .rightToLeft ? options.reversed() : options).map {
                          localizer.string($0.label)
                      }, width: width)
            .fixedSize()
        #else
        ViewThatFits(in: .horizontal) {
            choices
            ScrollView(.horizontal) { choices.fixedSize(horizontal: true, vertical: false) }
                .scrollIndicators(.hidden)
        }
        .frame(maxWidth: width)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localizer.string(key))
        #endif
    }

    #if os(iOS)
    private var choices: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    AppFeedback.selection()
                    selection = option.value
                } label: {
                    Text(localizer.string(option.label))
                        .font(.subheadline.weight(selection == option.value ? .semibold : .medium))
                        .foregroundStyle(selection == option.value ? AppColors.accentContrast : AppColors.textSecondary)
                        .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selection == option.value {
                                RoundedRectangle(cornerRadius: 12).fill(AppColors.accent)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    #endif

    #if os(macOS)

    private struct NativeControl: NSViewRepresentable {
        let label: String
        @Binding var selection: Value
        let isEnabled: Bool
        let options: [Option]
        let labels: [String]
        let width: CGFloat?

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        func makeNSView(context: Context) -> NSSegmentedControl {
            let control = NSSegmentedControl()
            control.trackingMode = .selectOne
            control.segmentStyle = .rounded
            control.target = context.coordinator
            control.action = #selector(Coordinator.changed(_:))
            return control
        }

        func updateNSView(_ control: NSSegmentedControl, context: Context) {
            context.coordinator.parent = self
            control.isEnabled = isEnabled
            if control.segmentCount != labels.count { control.segmentCount = labels.count }
            control.setAccessibilityLabel(label)
            control.selectedSegmentBezelColor = NSColor(AppColors.accent)
            for (index, title) in labels.enumerated() {
                if control.label(forSegment: index) != title { control.setLabel(title, forSegment: index) }
                let width = segmentWidth(title)
                if control.width(forSegment: index) != width { control.setWidth(width, forSegment: index) }
            }
            let selected = options.firstIndex { $0.value == selection } ?? -1
            if control.selectedSegment != selected { control.selectedSegment = selected }
        }

        func sizeThatFits(
            _ proposal: ProposedViewSize,
            nsView: NSSegmentedControl,
            context: Context
        ) -> CGSize? {
            CGSize(width: labels.reduce(CGFloat.zero) { $0 + segmentWidth($1) },
                   height: nsView.intrinsicContentSize.height)
        }

        private func segmentWidth(_ title: String) -> CGFloat {
            if let width { return width / CGFloat(max(1, labels.count)) }
            let font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            return ceil((title as NSString).size(withAttributes: [.font: font]).width)
                + AppDimensions.Spacing.large * 2
        }
    }

    private final class Coordinator: NSObject {
        var parent: NativeControl
        init(_ parent: NativeControl) { self.parent = parent }

        @objc func changed(_ control: NSSegmentedControl) {
            guard parent.options.indices.contains(control.selectedSegment) else { return }
            parent.selection = parent.options[control.selectedSegment].value
        }
    }
    #endif
}
