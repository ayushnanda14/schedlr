import Foundation
import SwiftData

@Model
final class GymScheduleDay {
    /// Calendar weekday: 1 = Sunday … 7 = Saturday
    var weekday: Int
    var splitDayRaw: String
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var splitDay: SplitDay {
        get { SplitDay(rawValue: splitDayRaw) ?? .rest }
        set { splitDayRaw = newValue.rawValue }
    }

    init(weekday: Int, splitDay: SplitDay) {
        self.weekday = weekday
        self.splitDayRaw = splitDay.rawValue
    }
}

extension GymScheduleDay: SyncableRecord {}
