import Foundation
import SwiftData

@Model
final class RoutineSuggestionRecord {
    var observationKindRaw: String = ObservationKind.morningGymConsistency.rawValue
    var title: String = ""
    var reason: String = ""
    var confidenceRaw: String = ConfidenceBand.low.rawValue
    var confidenceCopy: String = ""
    var proposedAction: String = ""
    var preferenceKeyRaw: String = LearnedPreferenceKey.preferMorningGym.rawValue
    var statusRaw: String = SuggestionRecordStatus.pending.rawValue
    var supportingCount: Int = 0
    var contraryCount: Int = 0
    var sampleCount: Int = 0
    var windowDays: Int = 14
    var rollbackJSON: String = ""
    var suppressedUntil: Date?
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var observationKind: ObservationKind {
        get { ObservationKind(rawValue: observationKindRaw) ?? .morningGymConsistency }
        set { observationKindRaw = newValue.rawValue }
    }

    var confidence: ConfidenceBand {
        get { ConfidenceBand(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }

    var preferenceKey: LearnedPreferenceKey {
        get { LearnedPreferenceKey(rawValue: preferenceKeyRaw) ?? .preferMorningGym }
        set { preferenceKeyRaw = newValue.rawValue }
    }

    var status: SuggestionRecordStatus {
        get { SuggestionRecordStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        observationKind: ObservationKind,
        title: String,
        reason: String,
        confidence: ConfidenceBand,
        confidenceCopy: String,
        proposedAction: String,
        preferenceKey: LearnedPreferenceKey,
        status: SuggestionRecordStatus = .pending,
        supportingCount: Int = 0,
        contraryCount: Int = 0,
        sampleCount: Int = 0,
        windowDays: Int = SuggestionPolicy.lookbackDays,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.observationKindRaw = observationKind.rawValue
        self.title = title
        self.reason = reason
        self.confidenceRaw = confidence.rawValue
        self.confidenceCopy = confidenceCopy
        self.proposedAction = proposedAction
        self.preferenceKeyRaw = preferenceKey.rawValue
        self.statusRaw = status.rawValue
        self.supportingCount = supportingCount
        self.contraryCount = contraryCount
        self.sampleCount = sampleCount
        self.windowDays = windowDays
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    func asSuggestion() -> RoutineSuggestion {
        RoutineSuggestion(
            id: id,
            observationKind: observationKind,
            title: title,
            reason: reason,
            confidence: confidence,
            confidenceCopy: confidenceCopy,
            proposedAction: proposedAction,
            preferenceKey: preferenceKey,
            editTarget: observationKind.editTarget
        )
    }
}

extension RoutineSuggestionRecord: SyncableRecord {}

@Model
final class SuggestionResponseEvent {
    var suggestionID: UUID = UUID()
    var kindRaw: String = SuggestionResponseKind.dismissed.rawValue
    var occurredAt: Date = Date()
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var kind: SuggestionResponseKind {
        get { SuggestionResponseKind(rawValue: kindRaw) ?? .dismissed }
        set { kindRaw = newValue.rawValue }
    }

    init(
        suggestionID: UUID,
        kind: SuggestionResponseKind,
        occurredAt: Date = Date()
    ) {
        self.suggestionID = suggestionID
        self.kindRaw = kind.rawValue
        self.occurredAt = occurredAt
        self.createdAt = occurredAt
        self.updatedAt = occurredAt
    }
}

extension SuggestionResponseEvent: SyncableRecord {}

@Model
final class LearnedPreference {
    var keyRaw: String = LearnedPreferenceKey.preferMorningGym.rawValue
    var isEnabled: Bool = true
    var rollbackJSON: String = ""
    var sourceSuggestionID: UUID?
    var explanation: String = ""
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var key: LearnedPreferenceKey {
        get { LearnedPreferenceKey(rawValue: keyRaw) ?? .preferMorningGym }
        set { keyRaw = newValue.rawValue }
    }

    init(
        key: LearnedPreferenceKey,
        isEnabled: Bool = true,
        rollbackJSON: String = "",
        sourceSuggestionID: UUID? = nil,
        explanation: String = "",
        createdAt: Date = Date()
    ) {
        self.keyRaw = key.rawValue
        self.isEnabled = isEnabled
        self.rollbackJSON = rollbackJSON
        self.sourceSuggestionID = sourceSuggestionID
        self.explanation = explanation
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension LearnedPreference: SyncableRecord {}

@Model
final class SuggestionPreferences {
    var morningGymEnabled: Bool = true
    var eveningPressureEnabled: Bool = true
    var repeatedSnoozeEnabled: Bool = true
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(
        morningGymEnabled: Bool = true,
        eveningPressureEnabled: Bool = true,
        repeatedSnoozeEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.morningGymEnabled = morningGymEnabled
        self.eveningPressureEnabled = eveningPressureEnabled
        self.repeatedSnoozeEnabled = repeatedSnoozeEnabled
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var enabledKinds: Set<ObservationKind> {
        var kinds: Set<ObservationKind> = []
        if morningGymEnabled { kinds.insert(.morningGymConsistency) }
        if eveningPressureEnabled { kinds.insert(.eveningSchedulePressure) }
        if repeatedSnoozeEnabled { kinds.insert(.repeatedSnooze) }
        return kinds
    }
}

extension SuggestionPreferences: SyncableRecord {}
