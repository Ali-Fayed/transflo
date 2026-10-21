import SwiftUI

/// A small indeterminate spinner for work in progress, such as a preview being rendered.
struct AppSpinner: View {
    var body: some View {
        ProgressView().controlSize(.small)
    }
}
