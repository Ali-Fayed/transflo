import Foundation
import os
import TransfloDomain
@preconcurrency import UserNotifications

/// Local notifications for finished jobs and available updates. Authorization is requested on
/// first use; activating a job notice reveals its files, and an update notice opens its link.
public final class UserNotificationPoster: NSObject, CompletionNotifying, UpdateNotifying,
    UNUserNotificationCenterDelegate, Sendable {
    static let pathsKey = "transflo.revealPaths"
    static let linkKey = "transflo.openLink"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "Notifications"
    )

    private let revealer: any FileRevealing
    private let opener: any URLOpening

    public init(revealer: any FileRevealing, opener: any URLOpening) {
        self.revealer = revealer
        self.opener = opener
        super.init()
    }

    /// Becomes the notification center's delegate so taps are handled. Call once at launch.
    public func activate() {
        UNUserNotificationCenter.current().delegate = self
    }

    public func notify(title: String, body: String, revealing urls: [URL]) {
        post(title: title, body: body, userInfo: [Self.pathsKey: urls.map(\.path)])
    }

    public func notifyUpdate(title: String, body: String, opening url: URL) {
        post(title: title, body: body, userInfo: [Self.linkKey: url.absoluteString])
    }

    private func post(title: String, body: String, userInfo: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error {
                Self.logger.error("Notification authorization failed: \(String(describing: error), privacy: .public)")
            }
            guard granted else { return }
            center.add(request)
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let link = Self.link(from: userInfo) {
            opener.open(link)
        } else {
            revealer.reveal(Self.urls(from: userInfo))
        }
    }

    static func urls(from userInfo: [AnyHashable: Any]) -> [URL] {
        (userInfo[pathsKey] as? [String] ?? []).map { URL(fileURLWithPath: $0) }
    }

    /// Only web and App Store links are opened, never files or other schemes.
    static func link(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let value = userInfo[linkKey] as? String, let url = URL(string: value),
              ["https", "macappstore"].contains(url.scheme?.lowercased()) else { return nil }
        return url
    }
}
