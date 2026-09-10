import Foundation
import SwiftData

@MainActor
protocol ScheduleRepository: AnyObject {
    func fetchActivities() -> [Activity]
    func fetchPlanTasks(includeClosed: Bool) -> [PlanTask]
    func fetchTimeBlocks(overlapping interval: DateInterval) -> [TimeBlock]
    func fetchConstraints(overlapping interval: DateInterval) -> [ScheduleConstraint]
    func fetchScheduleChanges(for timeBlockID: UUID) -> [ScheduleChangeEvent]
    func activity(id: UUID) -> Activity?
    func planTask(id: UUID) -> PlanTask?
    func timeBlock(id: UUID) -> TimeBlock?
    func fetchExceptions(overlapping interval: DateInterval) -> [DayException]
    func exception(id: UUID) -> DayException?

    @discardableResult func createActivity(_ draft: ActivityDraft) throws -> Activity
    @discardableResult func createPlanTask(_ draft: PlanTaskDraft) throws -> PlanTask
    @discardableResult func createTimeBlock(_ draft: TimeBlockDraft) throws -> TimeBlock
    @discardableResult func createConstraint(_ draft: ScheduleConstraintDraft) throws -> ScheduleConstraint
    @discardableResult func createException(_ draft: DayExceptionDraft) throws -> DayException
    func updateException(_ exception: DayException, title: String, startAt: Date, endAt: Date) throws
    func updateActivity(_ activity: Activity, title: String)
    func updatePlanTask(_ task: PlanTask, title: String, durationMinutes: Int, deadline: Date?, preferredStartAt: Date?, priority: PlanTaskPriority)
    func updateTimeBlock(_ block: TimeBlock, startAt: Date, endAt: Date, reason: String, provenance: TimeBlockProvenance?) throws
    func removeCapturedItem(timeBlockID: UUID?, activityID: UUID?, planTaskID: UUID?, exceptionID: UUID?)
    func softDeleteScheduleRecord(_ record: any SyncableRecord)
}

extension LocalSwiftDataStore: ScheduleRepository {
    func fetchActivities() -> [Activity] {
        fetch(Activity.self).filter { !isSoftDeleted($0) }.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchPlanTasks(includeClosed: Bool = false) -> [PlanTask] {
        fetch(PlanTask.self)
            .filter { !isSoftDeleted($0) && (includeClosed || $0.status == .open) }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return (lhs.deadline ?? .distantFuture) < (rhs.deadline ?? .distantFuture)
            }
    }

    func fetchTimeBlocks(overlapping interval: DateInterval) -> [TimeBlock] {
        fetch(TimeBlock.self)
            .filter { !isSoftDeleted($0) && $0.startAt < interval.end && $0.endAt > interval.start }
            .sorted { $0.startAt < $1.startAt }
    }

    func fetchConstraints(overlapping interval: DateInterval) -> [ScheduleConstraint] {
        fetch(ScheduleConstraint.self)
            .filter { !isSoftDeleted($0) && $0.startAt < interval.end && $0.endAt > interval.start }
            .sorted { $0.startAt < $1.startAt }
    }

    func fetchScheduleChanges(for timeBlockID: UUID) -> [ScheduleChangeEvent] {
        fetch(ScheduleChangeEvent.self)
            .filter { !isSoftDeleted($0) && $0.timeBlockID == timeBlockID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func activity(id: UUID) -> Activity? {
        fetchActivities().first { $0.id == id }
    }

    func planTask(id: UUID) -> PlanTask? {
        fetchPlanTasks(includeClosed: true).first { $0.id == id }
    }

    func timeBlock(id: UUID) -> TimeBlock? {
        fetch(TimeBlock.self).first { $0.id == id && !isSoftDeleted($0) }
    }

    func fetchExceptions(overlapping interval: DateInterval) -> [DayException] {
        fetch(DayException.self)
            .filter { !isSoftDeleted($0) && $0.startAt < interval.end && $0.endAt > interval.start }
            .sorted { $0.startAt < $1.startAt }
    }

    func exception(id: UUID) -> DayException? {
        fetch(DayException.self).first { $0.id == id && !isSoftDeleted($0) }
    }

    @discardableResult
    func createActivity(_ draft: ActivityDraft) throws -> Activity {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScheduleRepositoryError.emptyTitle
        }
        let activity = Activity(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: draft.kind,
            notes: draft.notes,
            isFixed: draft.isFixed,
            createdAt: clock.now
        )
        context.insert(activity)
        saveScheduleChanges()
        return activity
    }

    @discardableResult
    func createPlanTask(_ draft: PlanTaskDraft) throws -> PlanTask {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScheduleRepositoryError.emptyTitle
        }
        guard draft.estimatedDurationMinutes > 0 else {
            throw ScheduleRepositoryError.invalidDuration
        }
        let task = PlanTask(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedDurationMinutes: draft.estimatedDurationMinutes,
            deadline: draft.deadline,
            earliestStartAt: draft.earliestStartAt,
            preferredStartAt: draft.preferredStartAt,
            priority: draft.priority,
            flexibility: draft.flexibility,
            notes: draft.notes,
            createdAt: clock.now
        )
        context.insert(task)
        saveScheduleChanges()
        return task
    }

    @discardableResult
    func createTimeBlock(_ draft: TimeBlockDraft) throws -> TimeBlock {
        guard draft.endAt > draft.startAt else { throw ScheduleRepositoryError.invalidTimeRange }
        guard !(draft.activityID != nil && draft.planTaskID != nil) else {
            throw ScheduleRepositoryError.invalidOwnerCombination
        }
        switch draft.kind {
        case .commitment:
            guard let activityID = draft.activityID else { throw ScheduleRepositoryError.missingActivity }
            guard fetchActivities().contains(where: { $0.id == activityID }) else {
                throw ScheduleRepositoryError.missingReferencedRecord
            }
        case .task:
            guard let taskID = draft.planTaskID else { throw ScheduleRepositoryError.missingPlanTask }
            guard fetchPlanTasks(includeClosed: true).contains(where: { $0.id == taskID }) else {
                throw ScheduleRepositoryError.missingReferencedRecord
            }
        case .buffer:
            guard draft.activityID == nil && draft.planTaskID == nil else {
                throw ScheduleRepositoryError.invalidOwnerCombination
            }
        }

        let block = TimeBlock(
            startAt: draft.startAt,
            endAt: draft.endAt,
            kind: draft.kind,
            activityID: draft.activityID,
            planTaskID: draft.planTaskID,
            isLocked: draft.isLocked,
            provenance: draft.provenance,
            createdAt: clock.now
        )
        context.insert(block)
        context.insert(ScheduleChangeEvent(
            timeBlockID: block.id,
            kind: .created,
            afterStartAt: block.startAt,
            afterEndAt: block.endAt,
            reason: "Created manually",
            createdAt: clock.now
        ))
        saveScheduleChanges()
        return block
    }

    @discardableResult
    func createConstraint(_ draft: ScheduleConstraintDraft) throws -> ScheduleConstraint {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScheduleRepositoryError.emptyTitle
        }
        guard draft.endAt > draft.startAt else { throw ScheduleRepositoryError.invalidTimeRange }
        let constraint = ScheduleConstraint(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: draft.kind,
            startAt: draft.startAt,
            endAt: draft.endAt,
            isHard: draft.isHard,
            createdAt: clock.now
        )
        context.insert(constraint)
        saveScheduleChanges()
        return constraint
    }

    @discardableResult
    func createException(_ draft: DayExceptionDraft) throws -> DayException {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScheduleRepositoryError.emptyTitle
        }
        guard draft.endAt > draft.startAt else { throw ScheduleRepositoryError.invalidTimeRange }
        let exception = DayException(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: draft.kind,
            startAt: draft.startAt,
            endAt: draft.endAt,
            temporaryMode: draft.temporaryMode,
            createdAt: clock.now
        )
        context.insert(exception)
        saveScheduleChanges()
        return exception
    }

    func updateActivity(_ activity: Activity, title: String) {
        activity.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.updatedAt = clock.now
        activity.syncStatusRaw = SyncStatus.notSynced.rawValue
        saveScheduleChanges()
    }

    func updatePlanTask(
        _ task: PlanTask,
        title: String,
        durationMinutes: Int,
        deadline: Date?,
        preferredStartAt: Date?,
        priority: PlanTaskPriority
    ) {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.estimatedDurationMinutes = durationMinutes
        task.deadline = deadline
        task.preferredStartAt = preferredStartAt
        task.priority = priority
        task.updatedAt = clock.now
        task.syncStatusRaw = SyncStatus.notSynced.rawValue
        saveScheduleChanges()
    }

    func updateTimeBlock(
        _ block: TimeBlock,
        startAt: Date,
        endAt: Date,
        reason: String,
        provenance: TimeBlockProvenance?
    ) throws {
        guard endAt > startAt else { throw ScheduleRepositoryError.invalidTimeRange }
        let beforeStart = block.startAt
        let beforeEnd = block.endAt
        block.startAt = startAt
        block.endAt = endAt
        if let provenance {
            block.provenance = provenance
        }
        block.updatedAt = clock.now
        block.syncStatusRaw = SyncStatus.notSynced.rawValue
        context.insert(ScheduleChangeEvent(
            timeBlockID: block.id,
            kind: beforeStart != startAt ? .moved : .resized,
            beforeStartAt: beforeStart,
            beforeEndAt: beforeEnd,
            afterStartAt: startAt,
            afterEndAt: endAt,
            reason: reason,
            createdAt: clock.now
        ))
        saveScheduleChanges()
    }

    func updateException(_ exception: DayException, title: String, startAt: Date, endAt: Date) throws {
        guard endAt > startAt else { throw ScheduleRepositoryError.invalidTimeRange }
        exception.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        exception.startAt = startAt
        exception.endAt = endAt
        exception.updatedAt = clock.now
        exception.syncStatusRaw = SyncStatus.notSynced.rawValue
        saveScheduleChanges()
    }

    func removeCapturedItem(timeBlockID: UUID?, activityID: UUID?, planTaskID: UUID?, exceptionID: UUID?) {
        if let timeBlockID, let block = timeBlock(id: timeBlockID) {
            context.insert(ScheduleChangeEvent(
                timeBlockID: block.id,
                kind: .cancelled,
                beforeStartAt: block.startAt,
                beforeEndAt: block.endAt,
                reason: "Removed manually",
                createdAt: clock.now
            ))
            markDeleted(block)
            let remaining = fetch(TimeBlock.self).filter {
                !isSoftDeleted($0) && $0.id != block.id && (
                    ($0.activityID != nil && $0.activityID == block.activityID) ||
                    ($0.planTaskID != nil && $0.planTaskID == block.planTaskID)
                )
            }
            if remaining.isEmpty {
                if let activityID = block.activityID, let activity = activity(id: activityID) {
                    markDeleted(activity)
                }
                if let taskID = block.planTaskID, let task = planTask(id: taskID) {
                    markDeleted(task)
                }
            }
        } else {
            if let activityID, let activity = activity(id: activityID) {
                markDeleted(activity)
            }
            if let planTaskID, let task = planTask(id: planTaskID) {
                markDeleted(task)
            }
            if let exceptionID, let exception = exception(id: exceptionID) {
                markDeleted(exception)
            }
        }
        saveScheduleChanges()
    }

    func softDeleteScheduleRecord(_ record: any SyncableRecord) {
        // SwiftData change tracking is most reliable when mutating concrete @Model
        // types directly rather than through protocol abstraction.
        if let activity = record as? Activity {
            markDeleted(activity)
        } else if let task = record as? PlanTask {
            markDeleted(task)
        } else if let block = record as? TimeBlock {
            markDeleted(block)
        } else if let constraint = record as? ScheduleConstraint {
            markDeleted(constraint)
        } else if let change = record as? ScheduleChangeEvent {
            markDeleted(change)
        } else if let exception = record as? DayException {
            markDeleted(exception)
        } else {
            record.markDeleted(at: clock.now)
        }
        saveScheduleChanges()
    }

    private func markDeleted(_ activity: Activity) {
        activity.isDeleted = true
        activity.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        activity.updatedAt = clock.now
    }

    private func markDeleted(_ task: PlanTask) {
        task.isDeleted = true
        task.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        task.updatedAt = clock.now
    }

    private func markDeleted(_ block: TimeBlock) {
        block.isDeleted = true
        block.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        block.updatedAt = clock.now
    }

    private func markDeleted(_ constraint: ScheduleConstraint) {
        constraint.isDeleted = true
        constraint.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        constraint.updatedAt = clock.now
    }

    private func markDeleted(_ change: ScheduleChangeEvent) {
        change.isDeleted = true
        change.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        change.updatedAt = clock.now
    }

    private func markDeleted(_ exception: DayException) {
        exception.isDeleted = true
        exception.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        exception.updatedAt = clock.now
    }

    private func saveScheduleChanges() {
        try? context.save()
    }

    private func isSoftDeleted(_ record: any SyncableRecord) -> Bool {
        record.syncStatus == .pendingDelete
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}
