import Foundation

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case work
    case commute
    case exercise
    case meal
    case sleep
    case outing
    case event
    case personal

    var id: String { rawValue }
}

enum PlanTaskPriority: String, Codable, CaseIterable, Identifiable, Comparable {
    case low
    case normal
    case high
    case urgent

    var id: String { rawValue }

    private var rank: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }

    static func < (lhs: PlanTaskPriority, rhs: PlanTaskPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum PlanTaskFlexibility: String, Codable, CaseIterable, Identifiable {
    case flexible
    case preferredTime
    case mustSchedule

    var id: String { rawValue }
}

enum PlanTaskStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case completed
    case cancelled

    var id: String { rawValue }
}

enum TimeBlockKind: String, Codable, CaseIterable, Identifiable {
    case commitment
    case task
    case buffer

    var id: String { rawValue }
}

enum TimeBlockProvenance: String, Codable, CaseIterable, Identifiable {
    case manual
    case routine
    case acceptedProposal

    var id: String { rawValue }
}

enum ScheduleConstraintKind: String, Codable, CaseIterable, Identifiable {
    case availability
    case quietHours
    case sleep
    case commute
    case protectedBuffer
    case unavailable

    var id: String { rawValue }
}

enum ScheduleChangeKind: String, Codable, CaseIterable, Identifiable {
    case created
    case moved
    case resized
    case locked
    case unlocked
    case cancelled
    case completed
    case restored

    var id: String { rawValue }
}

struct ActivityDraft: Sendable, Equatable {
    var title: String
    var kind: ActivityKind
    var notes: String?
    var isFixed: Bool

    init(title: String, kind: ActivityKind = .personal, notes: String? = nil, isFixed: Bool = true) {
        self.title = title
        self.kind = kind
        self.notes = notes
        self.isFixed = isFixed
    }
}

struct PlanTaskDraft: Sendable, Equatable {
    var title: String
    var estimatedDurationMinutes: Int
    var deadline: Date?
    var earliestStartAt: Date?
    var preferredStartAt: Date?
    var priority: PlanTaskPriority
    var flexibility: PlanTaskFlexibility
    var notes: String?

    init(
        title: String,
        estimatedDurationMinutes: Int,
        deadline: Date? = nil,
        earliestStartAt: Date? = nil,
        preferredStartAt: Date? = nil,
        priority: PlanTaskPriority = .normal,
        flexibility: PlanTaskFlexibility = .flexible,
        notes: String? = nil
    ) {
        self.title = title
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.deadline = deadline
        self.earliestStartAt = earliestStartAt
        self.preferredStartAt = preferredStartAt
        self.priority = priority
        self.flexibility = flexibility
        self.notes = notes
    }
}

struct TimeBlockDraft: Sendable, Equatable {
    var startAt: Date
    var endAt: Date
    var kind: TimeBlockKind
    var activityID: UUID?
    var planTaskID: UUID?
    var isLocked: Bool
    var provenance: TimeBlockProvenance

    init(
        startAt: Date,
        endAt: Date,
        kind: TimeBlockKind,
        activityID: UUID? = nil,
        planTaskID: UUID? = nil,
        isLocked: Bool = false,
        provenance: TimeBlockProvenance = .manual
    ) {
        self.startAt = startAt
        self.endAt = endAt
        self.kind = kind
        self.activityID = activityID
        self.planTaskID = planTaskID
        self.isLocked = isLocked
        self.provenance = provenance
    }
}

struct ScheduleConstraintDraft: Sendable, Equatable {
    var title: String
    var kind: ScheduleConstraintKind
    var startAt: Date
    var endAt: Date
    var isHard: Bool

    init(
        title: String,
        kind: ScheduleConstraintKind,
        startAt: Date,
        endAt: Date,
        isHard: Bool = true
    ) {
        self.title = title
        self.kind = kind
        self.startAt = startAt
        self.endAt = endAt
        self.isHard = isHard
    }
}

enum ScheduleRepositoryError: LocalizedError, Equatable {
    case emptyTitle
    case invalidDuration
    case invalidTimeRange
    case missingActivity
    case missingPlanTask
    case invalidOwnerCombination
    case missingReferencedRecord

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "A schedule item needs a title."
        case .invalidDuration: return "A task duration must be greater than zero."
        case .invalidTimeRange: return "The end time must be after the start time."
        case .missingActivity: return "A commitment block needs an activity."
        case .missingPlanTask: return "A task block needs a task."
        case .invalidOwnerCombination: return "A time block can belong to one schedule item at a time."
        case .missingReferencedRecord: return "The linked schedule item no longer exists."
        }
    }
}
