import SwiftUI

/// A collapsible section whose title is copy or data, such as a file name.
struct AppDisclosure<Content: View>: View {
    let label: AppTextContent
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup {
            content()
        } label: {
            AppText(label).fixedSize(horizontal: false, vertical: true)
        }
    }
}
