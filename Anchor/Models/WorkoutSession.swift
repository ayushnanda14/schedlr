import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date
    var splitDayRaw: String
    var notes: String?
    var isDeload: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var setLogs: [SetLog]
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var splitDay: SplitDay {
        get { SplitDay(rawValue: splitDayRaw) ?? .rest }
        set { splitDayRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        splitDay: SplitDay,
        notes: String? = nil,
        isDeload: Bool = false,
        setLogs: [SetLog] = []
    ) {
        self.date = date
        self.splitDayRaw = splitDay.rawValue
        self.notes = notes
        self.isDeload = isDeload
        self.setLogs = setLogs
    }
}

extension WorkoutSession: SyncableRecord {}
