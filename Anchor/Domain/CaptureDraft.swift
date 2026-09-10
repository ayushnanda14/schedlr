import Foundation

enum CaptureField: String, Hashable, CaseIterable {
    case title
    case day
    case startTime
    case duration
    case deadline
    case priority
    case intent
}

enum CaptureIntent: String, Equatable {
    case commitment
    case flexibleTask
    case ambiguous
}

enum CaptureResult: Equatable {
    case empty
    case parsed(CaptureDraft)
    case invalid(String)
}

struct CaptureDraft: Equatable {
    var rawText: String
    var title: String
    var day: Date
    var startHour: Int?
    var startMinute: Int?
    var durationMinutes: Int?
    var deadline: Date?
    var priority: PlanTaskPriority
    var intent: CaptureIntent
    var inferred: Set<CaptureField>
    var userEdited: Set<CaptureField>
    var exceptionKind: DayExceptionKind? = nil

    var hasStartTime: Bool { startHour != nil }

    func startAt(calendar: Calendar) -> Date? {
        guard let startHour else { return nil }
        return calendar.date(
            bySettingHour: startHour,
            minute: startMinute ?? 0,
            second: 0,
            of: day
        )
    }

    func endAt(calendar: Calendar) -> Date? {
        guard let start = startAt(calendar: calendar) else { return nil }
        let minutes = max(durationMinutes ?? 30, 1)
        return calendar.date(byAdding: .minute, value: minutes, to: start)
    }

    func mergingUserEdits(from previous: CaptureDraft) -> CaptureDraft {
        var merged = self
        merged.userEdited = previous.userEdited
        for field in previous.userEdited {
            switch field {
            case .title: merged.title = previous.title
            case .day: merged.day = previous.day
            case .startTime:
                merged.startHour = previous.startHour
                merged.startMinute = previous.startMinute
            case .duration: merged.durationMinutes = previous.durationMinutes
            case .deadline: merged.deadline = previous.deadline
            case .priority: merged.priority = previous.priority
            case .intent: merged.intent = previous.intent
            }
            merged.inferred.remove(field)
        }
        merged.exceptionKind = previous.exceptionKind
        return merged
    }

    mutating func apply(_ field: CaptureField) {
        userEdited.insert(field)
        inferred.remove(field)
    }
}

enum CaptureError: LocalizedError, Equatable {
    case emptyTitle
    case ambiguousIntent
    case invalidTimeRange

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Add a short title first."
        case .ambiguousIntent: return "Choose whether this is a commitment or a flexible task."
        case .invalidTimeRange: return "The end time must be after the start time."
        }
    }
}

struct CaptureConfirmation: Equatable {
    var title: String
    var summary: String
    var conflictWarning: String?
}
