import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile
import UIKit

@Suite("Mobile conversion integration")
struct MobileConversionFlowTests {
    @Test("import, tap PNG, finish a real conversion and share its output")
    func convertAndShare() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("photo.jpg")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        }
        let original = try #require(image.jpegData(compressionQuality: 0.9))
        try original.write(to: source)
        let suite = "mobile-flow-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sut = MobileContainer(defaults: defaults, documents: root.appendingPathComponent("Documents"))

        await sut.screens.home.receive([source])
        #expect(sut.wheel.presenter.isShown)
        let slots = sut.wheel.viewModel.state.slots
        let index = try #require(slots.firstIndex { slot in
            guard case .option(let option) = slot, case .format(let format) = option.kind else { return false }
            return format.id == FormatID("png")
        })
        let geometry = sut.wheel.viewModel.state.geometry
        let angle = geometry.centerAngle(ofWedge: index) * .pi / 180
        let radius = (geometry.innerRadius + geometry.outerRadius) / 2
        #expect(sut.wheel.presenter.tap(at: WheelPoint(x: radius * sin(angle), y: radius * cos(angle))))
        #expect(!sut.wheel.presenter.isShown)

        let deadline = ContinuousClock.now + .seconds(10)
        while !sut.screens.jobs.hasFinishedJobs, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let job = try #require(sut.screens.jobs.rows.first)
        #expect(!job.isFailed && job.canReveal)
        while sut.coordinator.sharing == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let output = try #require(sut.coordinator.sharing?.urls.first)
        #expect(output.pathExtension == "png")
        #expect(try Data(contentsOf: output).prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]))
        #expect(UIImage(contentsOfFile: output.path)?.size == image.size)
        #expect(try Data(contentsOf: source) == original)
    }
}
