import Foundation

enum ProposalStatus: String, Equatable {
    case pending
    case accepted
    case dismissed
    case undone
}

enum PlanChangeKind: String, Equatable {
    case moved
    case deferred
}

struct PlanningPolicy: Equatable, Sendable {
    var dayStartHour: Int
    var dayEndHour: Int
    var buffer: BufferPolicy

    var gapMinutes: Int { buffer.minimumGapMinutes }

    static let `default` = PlanningPolicy(
        dayStartHour: 6,
        dayEndHour: 23,
        buffer: .default
    )
}

struct BufferPolicy: Equatable, Sendable {
    var minimumGapMinutes: Int
    var sleepBufferMinutes: Int
    var quietHoursStartHour: Int
    var quietHoursEndHour: Int

    static let `default` = BufferPolicy(
        minimumGapMinutes: 15,
        sleepBufferMinutes: 45,
        quietHoursStartHour: 22,
        quietHoursEndHour: 6
    )
}

enum SchedulePressureState: String, Equatable {
    case feasible
    case tight
    case oversubscribed
}

struct SchedulePressure: Equatable, Sendable {
    var fixedMinutes: Int
    var lockedMinutes: Int
    var flexiblePlannedMinutes: Int
    var usableMinutes: Int
    var protectedBufferMinutes: Int
    var flexibleItemCount: Int
    var state: SchedulePressureState

    var summary: String? {
        switch state {
        case .feasible:
            return nil
        case .tight:
            return "Tonight is tight; there is little room left after buffers."
        case .oversubscribed:
            if flexibleItemCount == 1 {
                return "Tonight is tight; one flexible task does not fit."
            }
            return "Tonight is tight; \(flexibleItemCount) flexible tasks do not fit."
        }
    }
}

enum DayExceptionKind: String, Codable, CaseIterable, Identifiable {
    case workRanLate
    case travel
    case matchEvent
    case social
    case unavailable
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .workRanLate: return "Work ran late"
        case .travel: return "Travel"
        case .matchEvent: return "Match / event"
        case .social: return "Social plan"
        case .unavailable: return "Unavailable"
        case .custom: return "Custom"
        }
    }

    var suggestedMode: AppMode? {
        switch self {
        case .travel, .unavailable: return .away
        default: return nil
        }
    }
}

enum DayExceptionEffect: String, Codable {
    case occupiesTime
}

struct DayExceptionPreset: Identifiable, Equatable {
    var id: String { kind.rawValue }
    var kind: DayExceptionKind
    var durationMinutes: Int
    var startHour: Int?

    static let all: [DayExceptionPreset] = [
        DayExceptionPreset(kind: .workRanLate, durationMinutes: 90, startHour: nil),
        DayExceptionPreset(kind: .travel, durationMinutes: 180, startHour: nil),
        DayExceptionPreset(kind: .matchEvent, durationMinutes: 150, startHour: 23),
        DayExceptionPreset(kind: .social, durationMinutes: 120, startHour: 19),
        DayExceptionPreset(kind: .unavailable, durationMinutes: 60, startHour: nil),
        DayExceptionPreset(kind: .custom, durationMinutes: 60, startHour: nil)
    ]
}

struct DayExceptionDraft: Equatable {
    var title: String
    var kind: DayExceptionKind
    var startAt: Date
    var endAt: Date
    var temporaryMode: AppMode?
}

struct PlanningBlock: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var startAt: Date
    var endAt: Date
    var isLocked: Bool
    var kind: TimeBlockKind
    var priority: PlanTaskPriority

    var isImmovable: Bool { isLocked || kind == .commitment }
    var duration: TimeInterval { endAt.timeIntervalSince(startAt) }
}

struct PlanChange: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var kind: PlanChangeKind
    var beforeStartAt: Date
    var beforeEndAt: Date
    var afterStartAt: Date?
    var afterEndAt: Date?
}

struct PlanProposal: Identifiable, Equatable, Sendable {
    var id: UUID
    var status: ProposalStatus
    var reason: String
    var triggerTitle: String?
    var changes: [PlanChange]
}

enum ExplanationFormatter {
    static func reason(triggerTitle: String?, changes: [PlanChange]) -> String {
        let moved = changes.filter { $0.kind == .moved }.map(\.title)
        let deferred = changes.filter { $0.kind == .deferred }.map(\.title)
        if let triggerTitle, !moved.isEmpty, deferred.isEmpty {
            if moved.count == 1 {
                return "This overlaps \(triggerTitle). I can move \(moved[0]) later today."
            }
            return "This overlaps \(triggerTitle). I can move \(moved.count) flexible items later today."
        }
        if !deferred.isEmpty, moved.isEmpty {
            if deferred.count == 1 {
                return "Tonight is tight. I can move \(deferred[0]) to tomorrow."
            }
            return "Tonight is tight. I can move \(deferred.count) flexible items to tomorrow."
        }
        if !changes.isEmpty {
            return "The remaining day is tight. I can move flexible items and leave fixed commitments in place."
        }
        return "The remaining day is tight."
    }
}
