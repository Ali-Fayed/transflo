import SwiftUI

/// The open wheel, composed from the view model's state.
struct WheelView: View {
    let viewModel: WheelViewModel
    var onActivate: ((Int) -> Void)?

    var body: some View {
        if let kind = viewModel.state.kind {
            AppRadialWheel(
                wedges: viewModel.state.slots.map(WheelPresentation.wedge(for:)),
                geometry: viewModel.state.geometry,
                highlightedIndex: viewModel.state.highlightedIndex,
                hubTitle: viewModel.hubTitle,
                hubGlyph: viewModel.hubGlyph,
                hubDetail: viewModel.hubDetail,
                itemCount: viewModel.state.summary?.itemCount ?? 1,
                onActivate: onActivate
            )
            .id("\(kind)-\(viewModel.state.group?.rawValue ?? "root")-\(viewModel.state.page)")
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }
}
