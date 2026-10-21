import Foundation
import TransfloDomain

/// Decorator over the job scheduler: scheduling a job keeps the provisional import it runs on.
final class ImportCommittingScheduler: JobScheduling {
    private let base: any JobScheduling
    private let imports: MobileProvisionalImport

    init(base: any JobScheduling, imports: MobileProvisionalImport) {
        self.base = base
        self.imports = imports
    }

    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint) {
        imports.commit()
        base.schedule(option, items: items, near: point)
    }
}
