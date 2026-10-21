import SwiftUI

struct PDFMarkupNavigation: View {
    let page: Int
    let count: Int
    let edited: Int
    let onSelect: (Int) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            HStack {
                AppButton(key: .pdfPreviousPage, variant: .tertiary, isEnabled: page > 0) { onSelect(page - 1) }
                Spacer()
                AppText(.pdfCurrentPage, arguments: [String(page + 1), String(count)], style: .caption)
                Spacer()
                AppButton(key: .pdfNextPage, variant: .tertiary, isEnabled: page + 1 < count) { onSelect(page + 1) }
            }
            AppText(.pdfEditedPages, arguments: [String(edited)], style: .caption, color: .secondary)
        }
    }
}
