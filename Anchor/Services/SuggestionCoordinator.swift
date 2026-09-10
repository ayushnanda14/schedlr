import Foundation
import SwiftData

@MainActor
struct SuggestionCoordinator {
    let store: LocalSwiftDataStore
    private let observationEngine: ObservationEngine
    private let suggestionEngine = SuggestionEngine()

    init(store: LocalSwiftDataStore) {
        self.store = store
        self.observationEngine = ObservationEngine(calendar: store.clock.calendar)
    }

    var clock: any AnchorClock { store.clock }
    var calendar: Calendar { clock.calendar }
    var now: Date { clock.now }

    func evaluate() -> RoutineSuggestion? {
        let observations = currentObservations()
        let context = decisionContext()
        guard var suggestion = suggestionEngine.suggest(observations: observations, context: context) else {
            expireStalePending(context: context, qualifying: Set(observations.map(\.kind)))
            return nil
        }
        suggestion = upsertPending(suggestion, observations: observations)
        expireStalePending(context: context, qualifying: Set(observations.map(\.kind)))
        return suggestion
    }

    func currentObservations() -> [RoutineObservation] {
        observationEngine.observe(facts: gatherFacts(), now: now)
    }

    func accept(
        _ suggestion: RoutineSuggestion,
        editedGymHour: Int? = nil,
        editedGymMinute: Int? = nil,
        editedSnoozeMinutes: Int? = nil
    ) -> UndoToken {
        let record = upsertPending(suggestion, observations: currentObservations())
        guard let stored = suggestionRecord(id: record.id) else {
            return UndoToken(message: "Saved.", kind: .learnedPreference(record.id))
        }

        let prefs = notificationPreferences()
        var rollback = PreferenceRollback()
        switch suggestion.observationKind {
        case .morningGymConsistency:
            let targetHour = editedGymHour ?? (prefs.gymHour > 9 ? SuggestionPolicy.defaultMorningGymHour : prefs.gymHour)
            let targetMinute = editedGymMinute ?? (editedGymHour == nil ? prefs.gymMinute : 0)
            if targetHour != prefs.gymHour || targetMinute != prefs.gymMinute {
                rollback.gymHour = prefs.gymHour
                rollback.gymMinute = prefs.gymMinute
                prefs.gymHour = targetHour
                prefs.gymMinute = targetMinute
                prefs.markDirty(at: now)
            }
        case .eveningSchedulePressure:
            break
        case .repeatedSnooze:
            let targetSnooze = editedSnoozeMinutes ?? max(prefs.snoozeMinutes, SuggestionPolicy.defaultSnoozeMinutes)
            if prefs.batchLowPriority != true || prefs.snoozeMinutes != targetSnooze {
                rollback.batchLowPriority = prefs.batchLowPriority
                rollback.snoozeMinutes = prefs.snoozeMinutes
                prefs.batchLowPriority = true
                prefs.snoozeMinutes = targetSnooze
                prefs.markDirty(at: now)
            }
        }

        stored.status = .accepted
        stored.rollbackJSON = rollback.json
        stored.suppressedUntil = nil
        stored.markDirty(at: now)

        upsertPreference(
            key: suggestion.preferenceKey,
            explanation: suggestion.reason,
            rollbackJSON: rollback.json,
            sourceSuggestionID: stored.id
        )
        logResponse(suggestionID: stored.id, kind: editedGymHour != nil || editedSnoozeMinutes != nil ? .edited : .accepted)
        store.save()
        NotificationScheduler.refreshSoon(context: store.context)

        return UndoToken(
            message: "Saved. You can undo this.",
            kind: .learnedPreference(stored.id)
        )
    }

    func dismiss(_ suggestion: RoutineSuggestion) {
        let stored = upsertPending(suggestion, observations: currentObservations())
        guard let record = suggestionRecord(id: stored.id) else { return }
        record.status = .dismissed
        record.suppressedUntil = calendar.date(byAdding: .day, value: SuggestionPolicy.suppressionDays, to: now)
        record.markDirty(at: now)
        logResponse(suggestionID: record.id, kind: .dismissed)
        store.save()
    }

    func undoAccept(suggestionID: UUID) {
        guard let record = suggestionRecord(id: suggestionID) else { return }
        restoreRollback(PreferenceRollback.parse(record.rollbackJSON))
        if let preference = activePreference(key: record.preferenceKey),
           preference.sourceSuggestionID == suggestionID {
            markDeleted(preference)
        }
        record.status = .undone
        record.suppressedUntil = calendar.date(byAdding: .day, value: SuggestionPolicy.suppressionDays, to: now)
        record.markDirty(at: now)
        logResponse(suggestionID: record.id, kind: .undone)
        store.save()
        NotificationScheduler.refreshSoon(context: store.context)
    }

    func resetPreference(_ key: LearnedPreferenceKey) {
        guard let preference = activePreference(key: key) else { return }
        restoreRollback(PreferenceRollback.parse(preference.rollbackJSON))
        markDeleted(preference)
        if let suggestionID = preference.sourceSuggestionID,
           let record = suggestionRecord(id: suggestionID) {
            record.status = .undone
            record.markDirty(at: now)
        }
        store.save()
        NotificationScheduler.refreshSoon(context: store.context)
    }

    func resetAllLearnedAssumptions() {
        for preference in learnedPreferences() {
            restoreRollback(PreferenceRollback.parse(preference.rollbackJSON))
            markDeleted(preference)
        }
        for record in suggestionRecords() where record.status == .accepted {
            record.status = .undone
            record.markDirty(at: now)
        }
        store.save()
        NotificationScheduler.refreshSoon(context: store.context)
    }

    func learnedPreferences() -> [LearnedPreference] {
        suggestionFetch(LearnedPreference.self)
            .filter { isActive($0) && $0.isEnabled }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func suggestionPreferences() -> SuggestionPreferences {
        if let existing = suggestionFetch(SuggestionPreferences.self).first(where: { isActive($0) }) {
            return existing
        }
        let prefs = SuggestionPreferences(createdAt: now)
        store.context.insert(prefs)
        store.save()
        return prefs
    }

    func notificationPreferences() -> NotificationPreferences {
        NotificationScheduler.ensurePreferences(in: store.context)
    }

    func persistSuggestionPreferences() {
        let prefs = suggestionPreferences()
        prefs.markDirty(at: now)
        store.save()
    }

    private func gatherFacts() -> ObservationFacts {
        ObservationFacts(
            gymCompletions: gymCompletionDates(),
            eveningPressureAt: eveningPressureDates(),
            snoozesAt: snoozeDates(),
            lowPriorityCompletionsAt: lowPriorityCompletionDates()
        )
    }

    private func gymCompletionDates() -> [Date] {
        var dates: [Date] = []
        for session in suggestionFetch(WorkoutSession.self) where isActive(session) && session.splitDay != .rest {
            dates.append(session.date)
        }

        let gymItemIDs = Set(
            suggestionFetch(DailyChecklistItem.self)
                .filter { isActive($0) && $0.category == .gym && $0.title.localizedCaseInsensitiveContains("gym session") }
                .map(\.id)
        )
        for event in suggestionFetch(ChecklistCompletionEvent.self) where isActive(event) && gymItemIDs.contains(event.checklistItemID) {
            dates.append(event.completedAt)
        }

        for event in suggestionFetch(ActivityCompletionEvent.self)
            where isActive(event) && event.kind == .completed && event.plannedTitle.localizedCaseInsensitiveContains("gym") {
            dates.append(event.occurredAt)
        }
        return dates
    }

    private func eveningPressureDates() -> [Date] {
        var dates: [Date] = []
        for change in suggestionFetch(ScheduleChangeEvent.self) where isActive(change) {
            let hour = calendar.component(.hour, from: change.createdAt)
            guard hour >= SuggestionPolicy.eveningPressureHour else { continue }
            let deferred: Bool
            if change.kind == .moved, let before = change.beforeStartAt, let after = change.afterStartAt {
                deferred = !calendar.isDate(before, inSameDayAs: after) && after > before
            } else {
                deferred = false
            }
            if deferred || change.kind == .cancelled {
                dates.append(change.createdAt)
            }
        }
        for exception in suggestionFetch(DayException.self) where isActive(exception) && exception.kind == .workRanLate {
            let startHour = calendar.component(.hour, from: exception.startAt)
            let endHour = calendar.component(.hour, from: exception.endAt)
            if startHour >= SuggestionPolicy.eveningPressureHour || endHour >= SuggestionPolicy.eveningPressureHour {
                dates.append(exception.startAt)
            }
        }
        return dates
    }

    private func snoozeDates() -> [Date] {
        suggestionFetch(ActionEvent.self)
            .filter { isActive($0) && $0.kind == .snoozed && isLowPriorityReminder($0.relatedRecordType) }
            .map(\.occurredAt)
    }

    private func lowPriorityCompletionDates() -> [Date] {
        suggestionFetch(ActionEvent.self)
            .filter { isActive($0) && $0.kind == .completed && isLowPriorityReminder($0.relatedRecordType) }
            .map(\.occurredAt)
    }

    private func isLowPriorityReminder(_ type: String) -> Bool {
        if type.isEmpty { return true }
        return type == NotificationKind.movement.rawValue
            || type == NotificationKind.periodicTask.rawValue
            || type == NotificationKind.periodicTaskBatch.rawValue
    }

    private func decisionContext() -> SuggestionContext {
        let prefs = notificationPreferences()
        let types = suggestionPreferences()
        var suppressed: [ObservationKind: Date] = [:]
        for record in suggestionRecords() {
            if let until = record.suppressedUntil, until > now {
                if let existing = suppressed[record.observationKind] {
                    suppressed[record.observationKind] = max(existing, until)
                } else {
                    suppressed[record.observationKind] = until
                }
            }
        }
        return SuggestionContext(
            now: now,
            acceptedPreferenceKeys: Set(learnedPreferences().map(\.key)),
            suppressedUntilByKind: suppressed,
            enabledKinds: types.enabledKinds,
            gymHour: prefs.gymHour,
            gymMinute: prefs.gymMinute,
            batchLowPriority: prefs.batchLowPriority,
            snoozeMinutes: prefs.snoozeMinutes
        )
    }

    @discardableResult
    private func upsertPending(_ suggestion: RoutineSuggestion, observations: [RoutineObservation]) -> RoutineSuggestion {
        let evidence = observations.first(where: { $0.kind == suggestion.observationKind })?.evidence
        if let existing = suggestionRecords().first(where: {
            $0.observationKind == suggestion.observationKind && $0.status == .pending
        }) {
            existing.title = suggestion.title
            existing.reason = suggestion.reason
            existing.confidence = suggestion.confidence
            existing.confidenceCopy = suggestion.confidenceCopy
            existing.proposedAction = suggestion.proposedAction
            existing.supportingCount = evidence?.supportingCount ?? existing.supportingCount
            existing.contraryCount = evidence?.contraryCount ?? existing.contraryCount
            existing.sampleCount = evidence?.sampleCount ?? existing.sampleCount
            existing.markDirty(at: now)
            store.save()
            return existing.asSuggestion()
        }

        let record = RoutineSuggestionRecord(
            id: suggestion.id,
            observationKind: suggestion.observationKind,
            title: suggestion.title,
            reason: suggestion.reason,
            confidence: suggestion.confidence,
            confidenceCopy: suggestion.confidenceCopy,
            proposedAction: suggestion.proposedAction,
            preferenceKey: suggestion.preferenceKey,
            supportingCount: evidence?.supportingCount ?? 0,
            contraryCount: evidence?.contraryCount ?? 0,
            sampleCount: evidence?.sampleCount ?? 0,
            createdAt: now
        )
        store.context.insert(record)
        store.save()
        return record.asSuggestion()
    }

    private func expireStalePending(context: SuggestionContext, qualifying: Set<ObservationKind>) {
        for record in suggestionRecords() where record.status == .pending {
            let kind = record.observationKind
            let stillEligible = qualifying.contains(kind)
                && context.enabledKinds.contains(kind)
                && !context.acceptedPreferenceKeys.contains(kind.preferenceKey)
            if !stillEligible {
                record.status = .dismissed
                record.markDirty(at: now)
            }
        }
        store.save()
    }

    private func upsertPreference(
        key: LearnedPreferenceKey,
        explanation: String,
        rollbackJSON: String,
        sourceSuggestionID: UUID
    ) {
        if let existing = activePreference(key: key) {
            existing.isEnabled = true
            existing.explanation = explanation
            existing.rollbackJSON = rollbackJSON
            existing.sourceSuggestionID = sourceSuggestionID
            existing.markDirty(at: now)
            return
        }
        let preference = LearnedPreference(
            key: key,
            rollbackJSON: rollbackJSON,
            sourceSuggestionID: sourceSuggestionID,
            explanation: explanation,
            createdAt: now
        )
        store.context.insert(preference)
    }

    private func restoreRollback(_ rollback: PreferenceRollback) {
        guard !rollback.isEmpty else { return }
        let prefs = notificationPreferences()
        if let hour = rollback.gymHour { prefs.gymHour = hour }
        if let minute = rollback.gymMinute { prefs.gymMinute = minute }
        if let batch = rollback.batchLowPriority { prefs.batchLowPriority = batch }
        if let snooze = rollback.snoozeMinutes { prefs.snoozeMinutes = snooze }
        prefs.markDirty(at: now)
    }

    private func logResponse(suggestionID: UUID, kind: SuggestionResponseKind) {
        store.context.insert(SuggestionResponseEvent(
            suggestionID: suggestionID,
            kind: kind,
            occurredAt: now
        ))
    }

    private func activePreference(key: LearnedPreferenceKey) -> LearnedPreference? {
        learnedPreferences().first(where: { $0.key == key })
    }

    private func suggestionRecord(id: UUID) -> RoutineSuggestionRecord? {
        suggestionRecords().first(where: { $0.id == id })
    }

    private func suggestionRecords() -> [RoutineSuggestionRecord] {
        suggestionFetch(RoutineSuggestionRecord.self).filter { isActive($0) }
    }

    private func suggestionFetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        store.fetch(type)
    }

    private func isActive(_ record: any SyncableRecord) -> Bool {
        !record.isDeleted && record.syncStatus != .pendingDelete
    }

    private func markDeleted(_ record: any SyncableRecord) {
        record.isDeleted = true
        record.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        record.updatedAt = now
    }
}
