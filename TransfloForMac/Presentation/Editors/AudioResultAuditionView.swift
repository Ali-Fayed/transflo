import Foundation
import SwiftUI

struct AudioResultAuditionView: View {
    let data: Data
    @State private var url: URL?
    @State private var playback = MediaAuditionController()
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(.audioPreviewHint, style: .caption, color: .secondary)
            HStack {
                AppButton(key: .audioPlayResult, variant: .tertiary, isEnabled: url != nil) {
                    playback.play(start: 0, end: 15, rate: 1)
                }
                AppButton(key: .mediaStop, variant: .tertiary) { playback.stop() }
            }
        }
        .task(id: data) {
            cleanUp()
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("audition-\(UUID()).wav")
            do {
                try data.write(to: target, options: .atomic)
                url = target; playback.load(target)
            } catch { url = nil }
        }
        .onDisappear { cleanUp() }
    }
    private func cleanUp() {
        playback.release()
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
}
