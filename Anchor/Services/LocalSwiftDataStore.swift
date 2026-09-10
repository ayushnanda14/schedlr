import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class LocalSwiftDataStore: DataStore {
    let context: ModelContext
    let clock: any AnchorClock

    init(context: ModelContext, clock: any AnchorClock = SystemAnchorClock()) {
        self.context = context
        self.clock = clock
    }

    func fetchChecklistItems(mode: AppMode) -> [DailyChecklistItem] {
        let items = (try? context.fetch(FetchDescriptor<DailyChecklistItem>())) ?? []
        return items.filter { !$0.isDeleted && $0.applicableModes.contains(mode) }
    }

    func logChecklistCompletion(itemID: UUID, mode: AppMode) {
        guard let item = checklist(id: itemID) else { return }
        let key = CompletionIdempotency.key(
            kind: "checklist",
            recordID: itemID,
            day: clock.now,
            calendar: clock.calendar
        )
        let already = checklistEvents(itemID: itemID).contains {
            $0.syncStatus != .pendingDelete &&
            ($0.idempotencyKey == key || clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now))
        }
        guard !already else { return }
        let event = ChecklistCompletionEvent(
            checklistItemID: itemID,
            completedAt: clock.now,
            modeAtCompletion: mode,
            idempotencyKey: key
        )
        context.insert(event)
        recomputeChecklist(item)
        save()
    }

    func undoChecklistCompletion(itemID: UUID) {
        var events = checklistEvents(itemID: itemID).filter {
            clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now) && $0.syncStatus != .pendingDelete
        }
        if events.isEmpty, let latest = checklistEvents(itemID: itemID)
            .filter({ $0.syncStatus != .pendingDelete })
            .sorted(by: { $0.completedAt > $1.completedAt })
            .first {
            events = [latest]
        }
        for event in events {
            markDeleted(event)
        }
        try? context.save()
        if let item = checklist(id: itemID) {
            recomputeChecklist(item)
        }
        save()
    }

    func toggleChecklistItem(itemID: UUID, mode: AppMode) {
        let completedToday = checklistEvents(itemID: itemID).contains {
            $0.syncStatus != .pendingDelete && clock.calendar.isDate($0.completedAt, inSameDayAs: clock.now)
        }
        if completedToday {
            undoChecklistCompletion(itemID: itemID)
        } else {
            logChecklistCompletion(itemID: itemID, mode: mode)
        }
    }

    func fetchPeriodicTasks(mode: AppMode) -> [PeriodicTask] {
        let tasks = (try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []
        return tasks.filter { !$0.isDeleted && $0.activeInModes.contains(mode) }
    }

    @discardableResult
    func logPeriodicTaskCompletion(taskID: UUID) -> CompletionWriteResult {
        guard let task = periodicTask(id: taskID) else { return .notFound }
        let key = CompletionIdempotency.key(
            kind: "periodic",
            recordID: taskID,
            day: clock.now,
            calendar: clock.calendar
        )
        let already = taskEvents(taskID: taskID).contains {
            $0.syncStatus != .pendingDelete && $0.idempotencyKey == key
        }
        if already { return .alreadyCompleted }
        context.insert(PeriodicTaskCompletionEvent(
            periodicTaskID: taskID,
            completedAt: clock.now,
            idempotencyKey: key
        ))
        recomputeTask(task)
        save()
        NotificationScheduler.refreshSoon(context: context)
        return .completed
    }

    func undoPeriodicTaskCompletion(taskID: UUID) {
        let key = CompletionIdempotency.key(
            kind: "periodic",
            recordID: taskID,
            day: clock.now,
            calendar: clock.calendar
        )
        let activeEvents = taskEvents(taskID: taskID).filter { $0.syncStatus != .pendingDelete }
        let target = activeEvents.first(where: { $0.idempotencyKey == key })
            ?? activeEvents.sorted { $0.completedAt > $1.completedAt }.first
        guard let target else { return }
        markDeleted(target)
        try? context.save()
        if let task = periodicTask(id: taskID) {
            recomputeTask(task)
        }
        save()
        NotificationScheduler.refreshSoon(context: context)
    }

    func recordNotificationOutcome(
        requestIdentifier: String,
        kind: NotificationKind,
        title: String,
        body: String,
        plannedFireAt: Date,
        relatedRecordID: UUID?,
        outcome: NotificationOutcome,
        source: ActionEventSource,
        snoozeMinutes: Int,
        at date: Date
    ) {
        context.insert(NotificationEvent(
            requestIdentifier: requestIdentifier,
            kind: kind,
            title: title,
            body: body,
            plannedFireAt: plannedFireAt,
            relatedRecordID: relatedRecordID,
            outcome: outcome,
            createdAt: date
        ))
        context.insert(ActionEvent(
            kind: outcome,
            source: source,
            relatedRecordID: relatedRecordID,
            relatedRecordType: kind.rawValue,
            occurredAt: date,
            snoozeMinutes: snoozeMinutes
        ))
        save()
    }

    func saveWeight(kg: Double, on date: Date, profile: UserProfile) {
        let entries = ((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []).filter { !$0.isDeleted }
        if let today = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            today.weightKg = kg
            today.markDirty()
        } else {
            context.insert(WeightEntry(date: date, weightKg: kg))
        }
        profile.weightKg = kg
        profile.markDirty()
        save()
    }

    @discardableResult
    func upsertSkincareNightLog(_ mutate: (SkincareNightLog) -> Void) -> SkincareNightLog {
        let logs = ((try? context.fetch(FetchDescriptor<SkincareNightLog>())) ?? []).filter { !$0.isDeleted }
        let log: SkincareNightLog
        if let existing = logs.first(where: { Calendar.current.isDateInToday($0.date) }) {
            log = existing
        } else {
            log = SkincareNightLog(date: Date())
            context.insert(log)
        }
        mutate(log)
        log.markDirty()
        save()
        return log
    }

    func ensureWorkoutSession(splitDay: SplitDay, notes: String?) -> WorkoutSession {
        let sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).filter { !$0.isDeleted }
        if let existing = WorkoutProgression.todaySession(splitDay: splitDay, sessions: sessions) {
            return existing
        }
        let session = WorkoutSession(date: Date(), splitDay: splitDay, notes: notes)
        context.insert(session)
        save()
        return session
    }

    func logSet(session: WorkoutSession, exerciseName: String, weightKg: Double, reps: Int, setNumber: Int) {
        if let existing = session.setLogs.first(where: {
            !$0.isDeleted && $0.exerciseName == exerciseName && $0.setNumber == setNumber
        }) {
            existing.weightKg = weightKg
            existing.reps = reps
            existing.markDirty()
        } else {
            let setLog = SetLog(
                exerciseName: exerciseName,
                weightKg: weightKg,
                reps: reps,
                setNumber: setNumber,
                session: session
            )
            context.insert(setLog)
            session.setLogs.append(setLog)
        }
        session.markDirty()
        save()
    }

    func updateWorkoutNotes(_ session: WorkoutSession, notes: String?) {
        session.notes = notes
        session.markDirty()
        save()
    }

    func markSessionDeload(_ session: WorkoutSession) {
        session.isDeload = true
        if session.notes == nil || session.notes?.isEmpty == true {
            session.notes = "Deload"
        }
        session.markDirty()
        save()
    }

    func persist(_ record: any SyncableRecord) {
        record.markDirty()
        save()
    }

    func fetchHistory(filter: HistoryFilter) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []

        let items = ((try? context.fetch(FetchDescriptor<DailyChecklistItem>())) ?? []).filter { !$0.isDeleted }
        let itemByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if filter == .all || filter == .gym || filter == .skincare {
            let events = ((try? context.fetch(FetchDescriptor<ChecklistCompletionEvent>())) ?? [])
                .filter { $0.syncStatus != .pendingDelete }
            for event in events {
                guard let item = itemByID[event.checklistItemID] else { continue }
                if filter == .gym && item.category != .gym { continue }
                if filter == .skincare && item.category != .skincareAM && item.category != .skincarePM { continue }
                entries.append(HistoryEntry(
                    id: UUID(),
                    filter: item.category == .gym ? .gym : .skincare,
                    date: event.completedAt,
                    title: item.title,
                    detail: event.modeAtCompletion.displayName,
                    systemImage: item.category == .gym ? "dumbbell" : (item.category == .skincareAM || item.category == .skincarePM ? "drop" : "checkmark.circle")
                ))
            }
        }

        if filter == .all || filter == .gym {
            let sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).filter { !$0.isDeleted }
            for session in sessions {
                let sets = session.setLogs.filter { !$0.isDeleted }
                let top = sets.max(by: { $0.weightKg < $1.weightKg })
                let detail: String
                if let top {
                    detail = "\(session.splitDay.displayName) · \(top.exerciseName) \(Int(top.weightKg)) kg × \(top.reps)"
                } else {
                    detail = session.splitDay.displayName
                }
                entries.append(HistoryEntry(
                    id: UUID(),
                    filter: .gym,
                    date: session.date,
                    title: "Workout",
                    detail: detail,
                    systemImage: "figure.strengthtraining.traditional",
                    workoutSessionID: session.id
                ))
            }
        }

        if filter == .all || filter == .skincare {
            let logs = ((try? context.fetch(FetchDescriptor<SkincareNightLog>())) ?? []).filter { !$0.isDeleted }
            for log in logs {
                entries.append(HistoryEntry(
                    id: UUID(),
                    filter: .skincare,
                    date: log.date,
                    title: "PM skincare",
                    detail: log.activeUsed ?? "No active",
                    systemImage: "drop.fill"
                ))
            }
        }

        if filter == .all || filter == .periodicTasks {
            let tasks = ((try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []).filter { !$0.isDeleted }
            let taskByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let events = ((try? context.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>())) ?? [])
                .filter { $0.syncStatus != .pendingDelete }
            for event in events {
                entries.append(HistoryEntry(
                    id: UUID(),
                    filter: .periodicTasks,
                    date: event.completedAt,
                    title: taskByID[event.periodicTaskID]?.title ?? "Task",
                    detail: "Completed",
                    systemImage: "house",
                    periodicTaskID: event.periodicTaskID
                ))
            }
        }

        if filter == .all || filter == .weight {
            let weights = ((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []).filter { !$0.isDeleted }
            for entry in weights {
                entries.append(HistoryEntry(
                    id: UUID(),
                    filter: .weight,
                    date: entry.date,
                    title: "Weight",
                    detail: String(format: "%.1f kg", entry.weightKg),
                    systemImage: "scalemass"
                ))
            }
        }

        return entries.sorted { $0.date > $1.date }
    }

    func heatmapCounts(weeks: Int) -> [Date: Int] {
        let calendar = Calendar.current
        let events = ((try? context.fetch(FetchDescriptor<ChecklistCompletionEvent>())) ?? [])
            .filter { $0.syncStatus != .pendingDelete }
        var counts: [Date: Int] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.completedAt)
            counts[day, default: 0] += 1
        }
        _ = weeks
        return counts
    }

    func workoutSession(id: UUID) -> WorkoutSession? {
        ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).first { $0.id == id && !$0.isDeleted }
    }

    func periodicTask(id: UUID) -> PeriodicTask? {
        ((try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []).first { $0.id == id && !$0.isDeleted }
    }

    func completionDates(forTaskID id: UUID) -> [Date] {
        ((try? context.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>())) ?? [])
            .filter { $0.syncStatus != .pendingDelete && $0.periodicTaskID == id }
            .map(\.completedAt)
            .sorted(by: >)
    }

    // MARK: - Private

    private func checklist(id: UUID) -> DailyChecklistItem? {
        ((try? context.fetch(FetchDescriptor<DailyChecklistItem>())) ?? []).first { $0.id == id && !$0.isDeleted }
    }

    private func checklistEvents(itemID: UUID) -> [ChecklistCompletionEvent] {
        ((try? context.fetch(FetchDescriptor<ChecklistCompletionEvent>())) ?? [])
            .filter { $0.checklistItemID == itemID }
    }

    private func taskEvents(taskID: UUID) -> [PeriodicTaskCompletionEvent] {
        ((try? context.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>())) ?? [])
            .filter { $0.periodicTaskID == taskID }
    }

    private func recomputeChecklist(_ item: DailyChecklistItem) {
        StreakMath.recompute(item: item, events: checklistEvents(itemID: item.id))
    }

    private func recomputeTask(_ task: PeriodicTask) {
        StreakMath.recompute(task: task, events: taskEvents(taskID: task.id))
    }

    private func save() {
        try? context.save()
    }

    private func markDeleted(_ event: ChecklistCompletionEvent) {
        event.isDeleted = true
        event.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        event.updatedAt = clock.now
    }

    private func markDeleted(_ event: PeriodicTaskCompletionEvent) {
        event.isDeleted = true
        event.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        event.updatedAt = clock.now
    }
}
