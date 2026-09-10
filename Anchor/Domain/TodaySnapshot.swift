import Foundation

struct TodaySnapshot: Sendable, Equatable {
    var now: Date
    var current: TodayTimelineItem?
    var next: TodayTimelineItem?
    var later: [TodayTimelineItem]

    var hasAnyPlannedItems: Bool {
        current != nil || next != nil || !later.isEmpty
    }
}

struct TodayTimelineItem: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable {
        case fixedCommitment
        case taskBlock
        case buffer
        case dayException
    }

        var id: UUID
        var title: String
        var detail: String
        var startAt: Date? = nil
        var endAt: Date? = nil
        var kind: Kind
        var isLocked: Bool
        var timeBlockID: UUID? = nil
        var activityID: UUID? = nil
        var planTaskID: UUID? = nil
        var exceptionID: UUID? = nil
        var isCorrected: Bool = false
        var plannedTitle: String? = nil
}
