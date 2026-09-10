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
        let composer = HistoryComposer()
        var facts: [HistoryEntry] = []

        let items = fetch(DailyChecklistItem.self).filter { !$0.isDeleted }
        let itemByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for event in fetch(ChecklistCompletionEvent.self).filter({ $0.syncStatus != .pendingDelete }) {
            guard let item = itemByID[event.checklistItemID] else { continue }
            let filterKind: HistoryFilter
            switch item.category {
            case .gym: filterKind = .gym
            case .skincareAM, .skincarePM: filterKind = .skincare
            default: filterKind = .all
            }
            facts.append(HistoryEntry(
                id: event.id,
                filter: filterKind,
                date: event.completedAt,
                title: item.title,
                detail: composer.detail(context: .completed, supporting: event.modeAtCompletion.displayName),
                systemImage: item.category == .gym ? "dumbbell" : (item.category == .skincareAM || item.category == .skincarePM ? "drop" : "checkmark.circle"),
                context: .completed
            ))
        }

        for session in fetch(WorkoutSession.self).filter({ !$0.isDeleted }) {
            let sets = session.setLogs.filter { !$0.isDeleted }
            let top = sets.max(by: { $0.weightKg < $1.weightKg })
            let supporting: String
            if let top {
                supporting = "\(session.splitDay.displayName) · \(top.exerciseName) \(Int(top.weightKg)) kg × \(top.reps)"
            } else {
                supporting = session.splitDay.displayName
            }
            facts.append(HistoryEntry(
                id: session.id,
                filter: .gym,
                date: session.date,
                title: "Workout",
                detail: composer.detail(context: .logged, supporting: supporting),
                systemImage: "figure.strengthtraining.traditional",
                context: .logged,
                workoutSessionID: session.id
            ))
        }

        for log in fetch(SkincareNightLog.self).filter({ !$0.isDeleted }) {
            facts.append(HistoryEntry(
                id: log.id,
                filter: .skincare,
                date: log.date,
                title: "PM active",
                detail: composer.detail(context: .logged, supporting: log.activeUsed ?? "No active"),
                systemImage: "drop.fill",
                context: .logged
            ))
        }

        let tasks = fetch(PeriodicTask.self).filter { !$0.isDeleted }
        let taskByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for event in fetch(PeriodicTaskCompletionEvent.self).filter({ $0.syncStatus != .pendingDelete }) {
            facts.append(HistoryEntry(
                id: event.id,
                filter: .periodicTasks,
                date: event.completedAt,
                title: taskByID[event.periodicTaskID]?.title ?? "Task",
                detail: composer.detail(context: .completed, supporting: ""),
                systemImage: "house",
                context: .completed,
                periodicTaskID: event.periodicTaskID
            ))
        }

        for entry in fetch(WeightEntry.self).filter({ !$0.isDeleted }) {
            facts.append(HistoryEntry(
                id: entry.id,
                filter: .weight,
                date: entry.date,
                title: "Weight",
                detail: composer.detail(context: .logged, supporting: String(format: "%.1f kg", entry.weightKg)),
                systemImage: "scalemass",
                context: .logged
            ))
        }

        let steps = Dictionary(
            fetch(RoutineStep.self).filter { !$0.isDeleted }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for event in fetch(RoutineCompletionEvent.self).filter({ $0.syncStatus != .pendingDelete }) {
            guard let step = steps[event.routineStepID] else { continue }
            facts.append(HistoryEntry(
                id: event.id,
                filter: .skincare,
                date: event.completedAt,
                title: step.title,
                detail: composer.detail(context: .completed, supporting: step.category == .skincarePM ? "Evening" : "Morning"),
                systemImage: "drop",
                context: .completed
            ))
        }

        for event in activeActivityEvents() {
            let context: HistoryEventContext = event.kind == .corrected ? .corrected : .completed
            let supporting: String
            if event.kind == .corrected {
                supporting = "Planned: \(event.plannedTitle) · Actual: \(event.actualTitle)"
            } else {
                supporting = event.plannedTitle
            }
            facts.append(HistoryEntry(
                id: event.id,
                filter: .schedule,
                date: event.occurredAt,
                title: event.kind == .corrected ? event.actualTitle : event.plannedTitle,
                detail: composer.detail(context: context, supporting: supporting),
                systemImage: event.kind == .corrected ? "arrow.triangle.2.circlepath" : "checkmark.circle",
                context: context
            ))
        }

        let completedBlockIDs = Set(
            activeActivityEvents().filter { $0.kind == .completed }.compactMap(\.timeBlockID)
        )
        let blocks = Dictionary(
            fetch(TimeBlock.self).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let activities = Dictionary(
            fetch(Activity.self).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let planTasks = Dictionary(
            fetch(PlanTask.self).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for change in fetch(ScheduleChangeEvent.self).filter({ $0.syncStatus != .pendingDelete }) {
            if change.kind == .completed, completedBlockIDs.contains(change.timeBlockID) {
                continue
            }
            guard let context = composer.context(
                for: change.kind,
                beforeStart: change.beforeStartAt,
                afterStart: change.afterStartAt,
                calendar: clock.calendar
            ) else { continue }
            let block = blocks[change.timeBlockID]
            let title = scheduleTitle(for: block, activities: activities, planTasks: planTasks)
            facts.append(HistoryEntry(
                id: change.id,
                filter: .schedule,
                date: change.createdAt,
                title: title,
                detail: composer.detail(context: context, supporting: change.reason ?? ""),
                systemImage: "calendar",
                context: context
            ))
        }

        return composer.compose(facts, filter: filter)
    }

    func historySnapshot(range: HistoryRange, filter: HistoryFilter) -> HistoryInsightSnapshot {
        let facts = fetchHistory(filter: .all)
        let interval = range.interval(now: clock.now, calendar: clock.calendar)
        let cadence = fetch(PeriodicTask.self)
            .filter { !$0.isDeleted }
            .map { task in
                HistoryCadenceInput(
                    id: task.id,
                    title: task.title,
                    cadenceDays: task.cadenceDays,
                    lastCompleted: task.lastCompletedDate,
                    datesInRange: completionDates(forTaskID: task.id).filter { interval.contains($0) }
                )
            }
        let workouts = fetch(WorkoutSession.self)
            .filter { !$0.isDeleted }
            .flatMap { session in
                session.setLogs.filter { !$0.isDeleted }.map { set in
                    HistoryWorkoutSample(
                        exerciseName: set.exerciseName,
                        date: session.date,
                        weightKg: set.weightKg,
                        reps: set.reps
                    )
                }
            }
        let weights = fetch(WeightEntry.self)
            .filter { !$0.isDeleted }
            .map { HistoryWeightSample(date: $0.date, weightKg: $0.weightKg) }
        let observations = SuggestionCoordinator(store: self).currentObservations()
        return HistoryInsightQuery(calendar: clock.calendar).snapshot(
            facts: facts,
            range: range,
            filter: filter,
            now: clock.now,
            cadence: cadence,
            workouts: workouts,
            weights: weights,
            observations: observations
        )
    }

    private func scheduleTitle(
        for block: TimeBlock?,
        activities: [UUID: Activity],
        planTasks: [UUID: PlanTask]
    ) -> String {
        if let activityID = block?.activityID, let activity = activities[activityID] {
            return activity.title
        }
        if let taskID = block?.planTaskID, let task = planTasks[taskID] {
            return task.title
        }
        return "Schedule"
    }

    func heatmapCounts(weeks: Int) -> [Date: Int] {
        let calendar = clock.calendar
        var counts: [Date: Int] = [:]
        let checklist = fetch(ChecklistCompletionEvent.self).filter { $0.syncStatus != .pendingDelete }
        let routine = fetch(RoutineCompletionEvent.self).filter { $0.syncStatus != .pendingDelete }
        let activity = activeActivityEvents().filter { $0.kind == .completed }
        for date in checklist.map(\.completedAt) + routine.map(\.completedAt) + activity.map(\.occurredAt) {
            let day = calendar.startOfDay(for: date)
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

    func save() {
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
