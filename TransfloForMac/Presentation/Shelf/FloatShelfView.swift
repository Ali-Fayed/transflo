import SwiftUI

/// The shelf: a header with the count, collapse and clear, then the files to drag back out.
/// Dropping more files on it adds them. Collapsed, it is a pill showing the count.
struct FloatShelfView: View {
    let viewModel: FloatShelfViewModel

    var body: some View {
        Group {
            if viewModel.isCollapsed {
                AppShelfPill(count: viewModel.items.count, onExpand: viewModel.toggleCollapsed)
            } else {
                AppShelfCard(
                    count: viewModel.items.count,
                    onCollapse: viewModel.toggleCollapsed,
                    onClear: viewModel.clear
                ) {
                    ForEach(viewModel.items, id: \.self) { url in
                        AppShelfTile(url: url) { viewModel.remove(url) }
                    }
                }
            }
        }
        .padding(AppDimensions.Wheel.margin)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.add(urls.filter(\.isFileURL))
            return true
        }
    }
}
