import Foundation

extension LocalSwiftDataStore {
    @discardableResult
    func logActivityCompletion(item: TodayTimelineItem) -> CompletionWriteResult {
        guard let timeBlockID = item.timeBlockID else { return .notFound }
        let key = "activity.completed.\(timeBlockID.uuidString)"
        if activeActivityEvents().contains(where: { $0.idempotencyKey == key }) {
            return .alreadyCompleted
        }
        let plannedTitle = item.plannedTitle ?? item.title
        context.insert(ActivityCompletionEvent(
            kind: .completed,
            timeBlockID: timeBlockID,
            activityID: item.activityID,
            planTaskID: item.planTaskID,
            exceptionID: item.exceptionID,
            plannedTitle: plannedTitle,
            actualTitle: plannedTitle,
            occurredAt: clock.now,
            idempotencyKey: key
        ))
        context.insert(ScheduleChangeEvent(
            timeBlockID: timeBlockID,
            kind: .completed,
            beforeStartAt: item.startAt,
            beforeEndAt: item.endAt,
            afterStartAt: item.startAt,
            afterEndAt: clock.now,
            reason: "Marked complete",
            createdAt: clock.now
        ))
        save()
        return .completed
    }

    @discardableResult
    func logActivityCorrection(item: TodayTimelineItem, actual: CurrentActivityKind) -> CompletionWriteResult {
        let plannedTitle = item.plannedTitle ?? item.title
        if let latest = latestCorrection(matching: item), latest.actualKind == actual {
            return .alreadyCompleted
        }
        context.insert(ActivityCompletionEvent(
            kind: .corrected,
            timeBlockID: item.timeBlockID,
            activityID: item.activityID,
            planTaskID: item.planTaskID,
            exceptionID: item.exceptionID,
            plannedTitle: plannedTitle,
            actualTitle: actual.displayName,
            actualKind: actual,
            occurredAt: clock.now,
            idempotencyKey: "activity.corrected.\(UUID().uuidString)"
        ))
        save()
        return .completed
    }

    func undoActivityEvent(id: UUID) {
        guard let event = activeActivityEvents().first(where: { $0.id == id }) else { return }
        markDeleted(event)
        if event.kind == .completed, let timeBlockID = event.timeBlockID {
            let audits = fetch(ScheduleChangeEvent.self).filter {
                $0.timeBlockID == timeBlockID
                    && $0.kind == .completed
                    && $0.syncStatus != .pendingDelete
            }
            audits.forEach { change in
                change.isDeleted = true
                change.syncStatusRaw = SyncStatus.pendingDelete.rawValue
                change.updatedAt = clock.now
            }
        }
        save()
    }

    func completedTimeBlockIDs(on day: Date) -> Set<UUID> {
        Set(
            activeActivityEvents()
                .filter { $0.kind == .completed && clock.calendar.isDate($0.occurredAt, inSameDayAs: day) }
                .compactMap(\.timeBlockID)
        )
    }

    func currentActivityOverride(for item: TodayTimelineItem?) -> CurrentActivityOverride? {
        if let item {
            guard let event = latestCorrection(matching: item) else { return nil }
            return override(from: event)
        }
        guard let event = activeActivityEvents()
            .filter({ $0.kind == .corrected && clock.calendar.isDate($0.occurredAt, inSameDayAs: clock.now) })
            .sorted(by: { $0.occurredAt > $1.occurredAt })
            .first
        else { return nil }
        return override(from: event)
    }

    func latestActivityEvent(kind: ActivityEventKind, matching item: TodayTimelineItem) -> ActivityCompletionEvent? {
        activeActivityEvents()
            .filter { $0.kind == kind && matches($0, item: item) }
            .sorted { $0.occurredAt > $1.occurredAt }
            .first
    }

    private func override(from event: ActivityCompletionEvent) -> CurrentActivityOverride {
        CurrentActivityOverride(
            timeBlockID: event.timeBlockID,
            exceptionID: event.exceptionID,
            plannedTitle: event.plannedTitle,
            actualTitle: event.actualTitle,
            actualKind: event.actualKind ?? .other
        )
    }

    private func latestCorrection(matching item: TodayTimelineItem) -> ActivityCompletionEvent? {
        activeActivityEvents()
            .filter { event in
                event.kind == .corrected
                    && clock.calendar.isDate(event.occurredAt, inSameDayAs: clock.now)
                    && matches(event, item: item)
            }
            .sorted { $0.occurredAt > $1.occurredAt }
            .first
    }

    private func matches(_ event: ActivityCompletionEvent, item: TodayTimelineItem) -> Bool {
        if let timeBlockID = item.timeBlockID, event.timeBlockID == timeBlockID { return true }
        if let exceptionID = item.exceptionID, event.exceptionID == exceptionID { return true }
        return false
    }

    func activeActivityEvents() -> [ActivityCompletionEvent] {
        fetch(ActivityCompletionEvent.self).filter { $0.syncStatus != .pendingDelete }
    }

    private func markDeleted(_ event: ActivityCompletionEvent) {
        event.isDeleted = true
        event.syncStatusRaw = SyncStatus.pendingDelete.rawValue
        event.updatedAt = clock.now
    }
}
