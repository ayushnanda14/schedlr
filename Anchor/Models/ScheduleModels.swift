import Foundation
import SwiftData

@Model
final class Activity {
    var title: String
    var kindRaw: String
    var notes: String?
    var isFixed: Bool
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: ActivityKind {
        get { ActivityKind(rawValue: kindRaw) ?? .personal }
        set { kindRaw = newValue.rawValue }
    }

    init(
        title: String,
        kind: ActivityKind = .personal,
        notes: String? = nil,
        isFixed: Bool = true,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.notes = notes
        self.isFixed = isFixed
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension Activity: SyncableRecord {}

@Model
final class PlanTask {
    var title: String
    var estimatedDurationMinutes: Int
    var deadline: Date?
    var earliestStartAt: Date?
    var preferredStartAt: Date?
    var priorityRaw: String
    var flexibilityRaw: String
    var statusRaw: String
    var notes: String?
    var completedAt: Date?
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var priority: PlanTaskPriority {
        get { PlanTaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var flexibility: PlanTaskFlexibility {
        get { PlanTaskFlexibility(rawValue: flexibilityRaw) ?? .flexible }
        set { flexibilityRaw = newValue.rawValue }
    }

    var status: PlanTaskStatus {
        get { PlanTaskStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    init(
        title: String,
        estimatedDurationMinutes: Int,
        deadline: Date? = nil,
        earliestStartAt: Date? = nil,
        preferredStartAt: Date? = nil,
        priority: PlanTaskPriority = .normal,
        flexibility: PlanTaskFlexibility = .flexible,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.deadline = deadline
        self.earliestStartAt = earliestStartAt
        self.preferredStartAt = preferredStartAt
        self.priorityRaw = priority.rawValue
        self.flexibilityRaw = flexibility.rawValue
        self.statusRaw = PlanTaskStatus.open.rawValue
        self.notes = notes
        self.completedAt = nil
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension PlanTask: SyncableRecord {}

@Model
final class TimeBlock {
    var startAt: Date
    var endAt: Date
    var kindRaw: String
    var activityID: UUID?
    var planTaskID: UUID?
    var isLocked: Bool
    var provenanceRaw: String
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: TimeBlockKind {
        get { TimeBlockKind(rawValue: kindRaw) ?? .buffer }
        set { kindRaw = newValue.rawValue }
    }

    var provenance: TimeBlockProvenance {
        get { TimeBlockProvenance(rawValue: provenanceRaw) ?? .manual }
        set { provenanceRaw = newValue.rawValue }
    }

    init(
        startAt: Date,
        endAt: Date,
        kind: TimeBlockKind,
        activityID: UUID? = nil,
        planTaskID: UUID? = nil,
        isLocked: Bool = false,
        provenance: TimeBlockProvenance = .manual,
        createdAt: Date = Date()
    ) {
        self.startAt = startAt
        self.endAt = endAt
        self.kindRaw = kind.rawValue
        self.activityID = activityID
        self.planTaskID = planTaskID
        self.isLocked = isLocked
        self.provenanceRaw = provenance.rawValue
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension TimeBlock: SyncableRecord {}

@Model
final class ScheduleConstraint {
    var title: String
    var kindRaw: String
    var startAt: Date
    var endAt: Date
    var isHard: Bool
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: ScheduleConstraintKind {
        get { ScheduleConstraintKind(rawValue: kindRaw) ?? .availability }
        set { kindRaw = newValue.rawValue }
    }

    init(
        title: String,
        kind: ScheduleConstraintKind,
        startAt: Date,
        endAt: Date,
        isHard: Bool = true,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.startAt = startAt
        self.endAt = endAt
        self.isHard = isHard
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension ScheduleConstraint: SyncableRecord {}

@Model
final class ScheduleChangeEvent {
    var timeBlockID: UUID
    var kindRaw: String
    var beforeStartAt: Date?
    var beforeEndAt: Date?
    var afterStartAt: Date?
    var afterEndAt: Date?
    var reason: String?
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var syncStatusRaw: String

    var kind: ScheduleChangeKind {
        get { ScheduleChangeKind(rawValue: kindRaw) ?? .created }
        set { kindRaw = newValue.rawValue }
    }

    init(
        timeBlockID: UUID,
        kind: ScheduleChangeKind,
        beforeStartAt: Date? = nil,
        beforeEndAt: Date? = nil,
        afterStartAt: Date? = nil,
        afterEndAt: Date? = nil,
        reason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.timeBlockID = timeBlockID
        self.kindRaw = kind.rawValue
        self.beforeStartAt = beforeStartAt
        self.beforeEndAt = beforeEndAt
        self.afterStartAt = afterStartAt
        self.afterEndAt = afterEndAt
        self.reason = reason
        self.id = UUID()
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isDeleted = false
        self.syncStatusRaw = SyncStatus.notSynced.rawValue
    }
}

extension ScheduleChangeEvent: SyncableRecord {}
