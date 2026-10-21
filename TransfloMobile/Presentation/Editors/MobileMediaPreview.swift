import AVFoundation
import SwiftUI
import UIKit

/// Source playback responds to trim, speed and frame controls; compression is applied only on export.
struct MobileMediaPreview: View {
    let model: MobileToolEditorModel
    private var playback: MobileMediaPlayback { model.playback }
    @State private var fullScreen = false
    @State private var fullScreenPosition = 0.0
    @Environment(Localizer.self) private var localizer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 14) {
            if model.isVideo {
                MobileVideoSurface(player: fullScreen ? nil : playback.player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.black, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel(localizer.string(.mediaSourcePreview))
                    .accessibilityIdentifier("mobile.video.preview")
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            AppFeedback.selection()
                            fullScreenPosition = playback.position
                            playback.isFullScreen = true
                            fullScreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.body.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(.black.opacity(0.65), in: Circle())
                        }
                        .padding(8)
                        .accessibilityLabel(localizer.string(.mobileFullScreen))
                        .accessibilityIdentifier("mobile.video.fullScreen")
                    }
            } else {
                Image(systemName: "waveform").font(.system(size: 42)).foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity).frame(height: 100).accessibilityHidden(true)
            }
            if playback.failed {
                AppText(.editorPreviewUnavailable, style: .caption, color: .danger)
            } else {
                transport
            }
            AppText(.mobilePlaybackHint, style: .caption, color: .secondary)
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 22))
        .task(id: model.items.first) {
            if let url = model.items.first, playback.loadedURL != url { await playback.load(url) }
        }
        .onDisappear {
            if !playback.isFullScreen { playback.stop() }
        }
        .fullScreenCover(isPresented: $fullScreen, onDismiss: finishedFullScreen) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    AppCloseButton(label: .mobileCloseFullScreen) {
                        fullScreenPosition = playback.position
                        fullScreen = false
                    }
                }
                MobileVideoSurface(player: playback.player).frame(maxHeight: .infinity)
                transport.padding(.bottom, 12)
            }
            .onAppear { playback.seek(fullScreenPosition) }
            .padding(.horizontal, 20)
            .background(AppColors.background.ignoresSafeArea())
            .accessibilityIdentifier("mobile.video.fullScreenPreview")
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
        .onChange(of: model.speed) { _, speed in
            if model.tool == .changeSpeed { playback.setRate(speed) }
        }
        .onChange(of: model.trimStart) { _, value in
            if model.tool == .trim { playback.pause(); playback.seek(value) }
        }
        .onChange(of: model.trimEnd) { previous, _ in
            // Loading metadata initializes the range; only an actual edit should seek to its end.
            if model.tool == .trim, previous > 0 { playback.pause(); playback.seek(model.trimStart) }
        }
        .onChange(of: model.snapshotTime) { _, value in
            if model.tool == .snapshot, abs(value - playback.position) > 0.001 {
                playback.pause(); playback.seek(value)
            }
        }
        .onChange(of: playback.position) { _, value in
            if model.tool == .snapshot { model.snapshotTime = value }
        }
    }

    private func finishedFullScreen() {
        playback.seek(fullScreenPosition)
        playback.isFullScreen = false
    }

    private var timeline: MobileMediaTimeline {
        MobileMediaTimeline(duration: playback.duration,
                            start: model.tool == .trim ? model.trimStart : 0,
                            end: model.tool == .trim && model.trimEnd > 0 ? model.trimEnd : playback.duration,
                            rate: model.tool == .changeSpeed ? model.speed : 1)
    }

    private func timestamp(_ seconds: Double) -> String {
        TimeLabel.wholeSeconds(seconds)
    }

    private var transport: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { timeline.elapsed(at: playback.position) },
                set: { playback.seek(timeline.sourceTime(at: $0)) }
            ),
                   in: 0...max(0.01, timeline.duration), onEditingChanged: { if $0 { playback.pause() } })
                .tint(AppColors.accent).frame(minHeight: 44)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel(localizer.string(.mobilePlaybackPosition))
                .accessibilityValue(timestamp(timeline.elapsed(at: playback.position)))
                .accessibilityIdentifier("mobile.video.scrubber")
            HStack {
                Text(timestamp(timeline.elapsed(at: playback.position))).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("mobile.video.time")
                control(.mobileSkipBack, symbol: "gobackward.5") {
                    skip(-5)
                }
                Button {
                    AppFeedback.selection()
                    playback.toggle(start: model.tool == .trim ? model.trimStart : 0,
                                    end: model.tool == .trim ? model.trimEnd : playback.duration,
                                    rate: model.tool == .changeSpeed ? model.speed : 1)
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title3).frame(width: 48, height: 48)
                        .foregroundStyle(AppColors.accentContrast)
                        .background(AppColors.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizer.string(playback.isPlaying ? .mobilePause : .mobilePlay))
                .accessibilityIdentifier("mobile.video.play")
                control(.mobileSkipForward, symbol: "goforward.5") {
                    skip(5)
                }
                Text(timestamp(timeline.duration))
                    .accessibilityIdentifier("mobile.video.duration").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.monospacedDigit()).foregroundStyle(AppColors.textSecondary)
            .disabled(playback.duration <= 0)
        }
    }

    private func skip(_ offset: Double) {
        AppFeedback.selection()
        playback.skip(offset * timeline.rate, start: model.tool == .trim ? model.trimStart : 0,
                      end: model.tool == .trim ? model.trimEnd : playback.duration)
    }

    private func control(_ label: L10nKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.title3).frame(width: 44, height: 44) }
            .buttonStyle(.plain).foregroundStyle(AppColors.textPrimary)
            .accessibilityLabel(localizer.string(label))
    }
}

/// The player layer keeps transport controls in our accessible editor instead of stacking two players' controls.
private struct MobileVideoSurface: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> Surface { Surface() }
    func updateUIView(_ view: Surface, context: Context) {
        if view.playerLayer?.player !== player { view.playerLayer?.player = player }
        view.playerLayer?.videoGravity = .resizeAspect
    }

    class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }
}
