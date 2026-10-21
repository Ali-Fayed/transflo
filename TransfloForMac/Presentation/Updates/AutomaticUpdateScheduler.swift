import Foundation
import TransfloDomain

/// Runs the automatic update check shortly after launch and then every hour while Transflo is
/// open; the use case limits real requests to one a day. A new version posts one notification
/// that opens the release page or the App Store.
final class AutomaticUpdateScheduler {
    private let check: AutomaticUpdateCheckUseCase
    private let notifier: any UpdateNotifying
    private let localizer: Localizer
    private let text: UpdateChannelText
    private let downloadURL: URL
    private let now: () -> Date
    private var task: Task<Void, Never>?

    init(
        check: AutomaticUpdateCheckUseCase,
        notifier: any UpdateNotifying,
        localizer: Localizer,
        text: UpdateChannelText,
        downloadURL: URL,
        now: @escaping () -> Date = Date.init
    ) {
        self.check = check
        self.notifier = notifier
        self.localizer = localizer
        self.text = text
        self.downloadURL = downloadURL
        self.now = now
    }

    deinit { task?.cancel() }

    func start(after delay: Duration = .seconds(30), every period: Duration = .seconds(60 * 60)) {
        guard task == nil else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: delay)
            while !Task.isCancelled {
                await self?.runOnce()
                try? await Task.sleep(for: period)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// One pass: ask (if due) and announce a version the user hasn't seen.
    func runOnce() async {
        guard let version = await check.execute(now: now()) else { return }
        notifier.notifyUpdate(
            title: localizer.string(.updateNotificationTitle, arguments: [version]),
            body: localizer.string(text.notificationBody),
            opening: downloadURL
        )
    }
}
