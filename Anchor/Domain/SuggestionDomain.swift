import Foundation

enum ObservationKind: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case morningGymConsistency
    case eveningSchedulePressure
    case repeatedSnooze

    var id: String { rawValue }

    var preferenceKey: LearnedPreferenceKey {
        switch self {
        case .morningGymConsistency: return .preferMorningGym
        case .eveningSchedulePressure: return .protectEveningBuffer
        case .repeatedSnooze: return .delayLowPriorityReminders
        }
    }

    var displayName: String {
        switch self {
        case .morningGymConsistency: return "Morning gym"
        case .eveningSchedulePressure: return "Evening pressure"
        case .repeatedSnooze: return "Repeated snooze"
        }
    }

    var editTarget: SuggestionEditTarget {
        switch self {
        case .morningGymConsistency: return .gymReminderTime
        case .eveningSchedulePressure: return .insightsOnly
        case .repeatedSnooze: return .notificationSettings
        }
    }
}

enum LearnedPreferenceKey: String, Codable, Equatable, CaseIterable, Identifiable, Sendable {
    case preferMorningGym
    case protectEveningBuffer
    case delayLowPriorityReminders

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preferMorningGym: return "Morning gym default"
        case .protectEveningBuffer: return "Protect evening buffer"
        case .delayLowPriorityReminders: return "Quieter low-priority reminders"
        }
    }

    var observationKind: ObservationKind {
        switch self {
        case .preferMorningGym: return .morningGymConsistency
        case .protectEveningBuffer: return .eveningSchedulePressure
        case .delayLowPriorityReminders: return .repeatedSnooze
        }
    }
}

enum ConfidenceBand: String, Codable, Equatable, Comparable, CaseIterable, Sendable {
    case low
    case moderate
    case high

    var displayName: String {
        switch self {
        case .low: return "Early signal"
        case .moderate: return "Repeated pattern"
        case .high: return "Consistent recently"
        }
    }

    static func < (lhs: ConfidenceBand, rhs: ConfidenceBand) -> Bool {
        lhs.rank < rhs.rank
    }

    var rank: Int {
        switch self {
        case .low: return 0
        case .moderate: return 1
        case .high: return 2
        }
    }
}

enum SuggestionResponseKind: String, Codable, Equatable, Sendable {
    case accepted
    case dismissed
    case edited
    case undone
}

enum SuggestionRecordStatus: String, Codable, Equatable, Sendable {
    case pending
    case accepted
    case dismissed
    case undone
}

enum SuggestionEditTarget: String, Equatable, Sendable {
    case gymReminderTime
    case notificationSettings
    case insightsOnly
}

enum SuggestionPolicy {
    static let lookbackDays = 14
    static let recentDays = 7
    static let suppressionDays = 14
    static let minGymSamples = 4
    static let morningHourExclusive = 12
    static let eveningGymHour = 16
    static let eveningPressureHour = 17
    static let minPressureDays = 3
    static let minSnoozes = 5
    static let defaultMorningGymHour = 7
    static let defaultSnoozeMinutes = 45
}

struct SuggestionEvidence: Equatable, Sendable {
    var supportingCount: Int
    var contraryCount: Int
    var sampleCount: Int
    var windowDays: Int
    var lastSeenAt: Date?
    var firstSeenAt: Date?
}

struct RoutineObservation: Identifiable, Equatable, Sendable {
    var id: ObservationKind { kind }
    var kind: ObservationKind
    var evidence: SuggestionEvidence
    var confidence: ConfidenceBand
    var reason: String
    var confidenceCopy: String
}

struct RoutineSuggestion: Identifiable, Equatable, Sendable {
    var id: UUID
    var observationKind: ObservationKind
    var title: String
    var reason: String
    var confidence: ConfidenceBand
    var confidenceCopy: String
    var proposedAction: String
    var preferenceKey: LearnedPreferenceKey
    var editTarget: SuggestionEditTarget
}

struct ObservationFacts: Equatable, Sendable {
    var gymCompletions: [Date]
    var eveningPressureAt: [Date]
    var snoozesAt: [Date]
    var lowPriorityCompletionsAt: [Date]

    static let empty = ObservationFacts(
        gymCompletions: [],
        eveningPressureAt: [],
        snoozesAt: [],
        lowPriorityCompletionsAt: []
    )
}

struct SuggestionContext: Equatable, Sendable {
    var now: Date
    var acceptedPreferenceKeys: Set<LearnedPreferenceKey>
    var suppressedUntilByKind: [ObservationKind: Date]
    var enabledKinds: Set<ObservationKind>
    var gymHour: Int
    var gymMinute: Int
    var batchLowPriority: Bool
    var snoozeMinutes: Int
}

struct PreferenceRollback: Codable, Equatable, Sendable {
    var gymHour: Int?
    var gymMinute: Int?
    var batchLowPriority: Bool?
    var snoozeMinutes: Int?

    var isEmpty: Bool {
        gymHour == nil && gymMinute == nil && batchLowPriority == nil && snoozeMinutes == nil
    }

    var json: String {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func parse(_ json: String) -> PreferenceRollback {
        guard let data = json.data(using: .utf8),
              let value = try? JSONDecoder().decode(PreferenceRollback.self, from: data) else {
            return PreferenceRollback()
        }
        return value
    }
}

enum SuggestionCopy {
    static let gymReason = "You completed gym more often before noon than later in the day."
    static let pressureReason = "Several evenings recently needed tasks moved later."
    static let snoozeReason = "Low-priority reminders were snoozed repeatedly."

    static let gymTitle = "Try a morning gym reminder?"
    static let pressureTitle = "Protect evenings when days run late?"
    static let snoozeTitle = "Give low-priority reminders more room?"

    static func gymConfidence(supporting: Int, sample: Int) -> String {
        "Based on \(supporting) of \(sample) gym days in the last 2 weeks."
    }

    static func pressureConfidence(days: Int) -> String {
        if days == 1 {
            return "Based on 1 tight evening in the last 2 weeks."
        }
        return "Based on \(days) tight evenings in the last 2 weeks."
    }

    static func snoozeConfidence(count: Int) -> String {
        if count == 1 {
            return "Based on 1 snooze in the last 2 weeks."
        }
        return "Based on \(count) snoozes in the last 2 weeks."
    }

    static func gymAction(currentHour: Int, currentMinute: Int) -> String {
        if currentHour > 9 {
            return "Set the gym reminder to 7:00 AM. You can undo this."
        }
        let minute = String(format: "%02d", currentMinute)
        return "Keep the gym reminder at \(currentHour):\(minute). You can reset this in Insights."
    }

    static func pressureAction() -> String {
        "Keep evenings lighter when a day runs late. Anchor will not move items on its own."
    }

    static func snoozeAction(batchLowPriority: Bool, snoozeMinutes: Int) -> String {
        if batchLowPriority && snoozeMinutes >= SuggestionPolicy.defaultSnoozeMinutes {
            return "Keep low-priority reminders quieter. You can reset this in Insights."
        }
        return "Batch low-priority reminders and give snooze 45 minutes. You can undo this."
    }
}
