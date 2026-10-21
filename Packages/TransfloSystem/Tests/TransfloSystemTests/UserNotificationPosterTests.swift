import Foundation
import Testing
@testable import TransfloSystem

@Suite("UserNotificationPoster")
struct UserNotificationPosterTests {
    @Test("revealed paths round-trip through the notification payload")
    func payload() {
        let info: [AnyHashable: Any] = [UserNotificationPoster.pathsKey: ["/tmp/a.png", "/tmp/b 2.png"]]
        #expect(UserNotificationPoster.urls(from: info).map(\.path) == ["/tmp/a.png", "/tmp/b 2.png"])
    }

    @Test("a payload without paths reveals nothing")
    func emptyPayload() {
        #expect(UserNotificationPoster.urls(from: [:]).isEmpty)
        #expect(UserNotificationPoster.urls(from: [UserNotificationPoster.pathsKey: 42]).isEmpty)
    }
}

@Suite("UserNotificationPoster update links")
struct UserNotificationPosterLinkTests {
    @Test("web and App Store links round-trip through the notification payload")
    func links() {
        for link in ["https://github.com/Ali-Fayed/transflo/releases/latest", "macappstore://apps.apple.com/app/id1"] {
            #expect(UserNotificationPoster.link(from: [UserNotificationPoster.linkKey: link])?.absoluteString == link)
        }
    }

    @Test("files, other schemes and malformed payloads are never opened")
    func rejectsUnsafeLinks() {
        for value: Any in ["file:///Applications/Calculator.app", "http://example.com", "ftp://x", "", 42] {
            #expect(UserNotificationPoster.link(from: [UserNotificationPoster.linkKey: value]) == nil)
        }
        #expect(UserNotificationPoster.link(from: [UserNotificationPoster.pathsKey: ["/tmp/a.png"]]) == nil)
    }
}
