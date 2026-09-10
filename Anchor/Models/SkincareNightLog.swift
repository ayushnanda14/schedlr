import Foundation
import SwiftData

@Model
final class SkincareNightLog {
    var date: Date
    var activeUsed: String?
    var irritationFlag: Bool
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(date: Date = Date(), activeUsed: String? = nil, irritationFlag: Bool = false) {
        self.date = date
        self.activeUsed = activeUsed
        self.irritationFlag = irritationFlag
    }
}

extension SkincareNightLog: SyncableRecord {}
