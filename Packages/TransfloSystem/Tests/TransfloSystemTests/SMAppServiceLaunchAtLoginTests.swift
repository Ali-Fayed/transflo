import ServiceManagement
import Testing
import TransfloDomain
@testable import TransfloSystem

@Suite("SMAppServiceLaunchAtLogin status mapping")
struct SMAppServiceLaunchAtLoginTests {
    @Test("only an enabled status counts as enabled")
    func enabledMapping() {
        #expect(SMAppServiceLaunchAtLogin.isEnabled(status: .enabled))
        #expect(SMAppServiceLaunchAtLogin.isEnabled(status: .requiresApproval) == false)
        #expect(SMAppServiceLaunchAtLogin.isEnabled(status: .notRegistered) == false)
        #expect(SMAppServiceLaunchAtLogin.isEnabled(status: .notFound) == false)
    }

    @Test("a failure while awaiting approval reports requiresApproval")
    func approvalError() {
        #expect(SMAppServiceLaunchAtLogin.error(afterFailureWith: .requiresApproval) == .requiresApproval)
    }

    @Test("any other failure reports failed", arguments: [SMAppService.Status.notRegistered, .notFound, .enabled])
    func genericError(status: SMAppService.Status) {
        #expect(SMAppServiceLaunchAtLogin.error(afterFailureWith: status) == .failed)
    }
}
