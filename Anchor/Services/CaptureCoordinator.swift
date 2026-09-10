import Foundation

@MainActor
struct CaptureCoordinator {
    let repository: any ScheduleRepository
    let clock: any AnchorClock
    let interpreter: CaptureInterpreter

    init(repository: any ScheduleRepository, clock: any AnchorClock) {
        self.repository = repository
        self.clock = clock
        self.interpreter = CaptureInterpreter(calendar: clock.calendar)
    }

    func confirm(_ draft: CaptureDraft) throws -> CaptureConfirmation {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CaptureError.emptyTitle }
        if draft.exceptionKind != nil {
            return try confirmException(draft)
        }
        guard draft.intent != .ambiguous else { throw CaptureError.ambiguousIntent }

        let calendar = clock.calendar
        let startAt = draft.startAt(calendar: calendar)
        let endAt = draft.endAt(calendar: calendar)
        if let startAt, let endAt, endAt <= startAt {
            throw CaptureError.invalidTimeRange
        }

        let conflictWarning = conflictMessage(startAt: startAt, endAt: endAt, ignoring: nil)

        switch draft.intent {
        case .commitment:
            let activity = try repository.createActivity(
                ActivityDraft(
                    title: title,
                    kind: interpreter.inferredActivityKind(from: title),
                    isFixed: true
                )
            )
            if let startAt, let endAt {
                _ = try repository.createTimeBlock(
                    TimeBlockDraft(
                        startAt: startAt,
                        endAt: endAt,
                        kind: .commitment,
                        activityID: activity.id,
                        isLocked: true
                    )
                )
            }
            return CaptureConfirmation(
                title: title,
                summary: summary(for: draft, kind: "Commitment"),
                conflictWarning: conflictWarning
            )

        case .flexibleTask:
            let task = try repository.createPlanTask(
                PlanTaskDraft(
                    title: title,
                    estimatedDurationMinutes: draft.durationMinutes ?? 30,
                    deadline: draft.deadline,
                    preferredStartAt: startAt,
                    priority: draft.priority,
                    flexibility: startAt == nil ? .flexible : .preferredTime
                )
            )
            if let startAt, let endAt {
                _ = try repository.createTimeBlock(
                    TimeBlockDraft(
                        startAt: startAt,
                        endAt: endAt,
                        kind: .task,
                        planTaskID: task.id
                    )
                )
            }
            return CaptureConfirmation(
                title: title,
                summary: summary(for: draft, kind: "Task"),
                conflictWarning: conflictWarning
            )

        case .ambiguous:
            throw CaptureError.ambiguousIntent
        }
    }

    private func confirmException(_ draft: CaptureDraft) throws -> CaptureConfirmation {
        let calendar = clock.calendar
        let kind = draft.exceptionKind ?? .custom
        guard let startAt = draft.startAt(calendar: calendar), let endAt = draft.endAt(calendar: calendar) else {
            throw CaptureError.invalidTimeRange
        }
        if endAt <= startAt { throw CaptureError.invalidTimeRange }
        _ = try repository.createException(
            DayExceptionDraft(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind,
                startAt: startAt,
                endAt: endAt,
                temporaryMode: kind.suggestedMode
            )
        )
        let warning = conflictMessage(startAt: startAt, endAt: endAt, ignoring: nil)
        let summary: String
        if kind.suggestedMode == nil {
            summary = "Exception · \(kind.displayName)"
        } else {
            summary = "Exception · \(kind.displayName). Mode stays as it is until you switch it."
        }
        return CaptureConfirmation(
            title: draft.title,
            summary: summary,
            conflictWarning: warning
        )
    }

    func update(
        item: TodayTimelineItem,
        title: String,
        day: Date,
        startHour: Int?,
        startMinute: Int?,
        durationMinutes: Int
    ) throws -> CaptureConfirmation {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CaptureError.emptyTitle }
        return try updateItem(
            item: item,
            title: trimmed,
            day: clock.calendar.startOfDay(for: day),
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes
        )
    }

    func remove(_ item: TodayTimelineItem) -> CaptureConfirmation {
        repository.removeCapturedItem(
            timeBlockID: item.timeBlockID,
            activityID: item.activityID,
            planTaskID: item.planTaskID,
            exceptionID: item.exceptionID
        )
        return CaptureConfirmation(title: item.title, summary: "Removed \(item.title)", conflictWarning: nil)
    }

    func shift(_ item: TodayTimelineItem, _ kind: ScheduleShift) throws -> CaptureConfirmation {
        let calendar = clock.calendar
        let now = clock.now
        let duration = durationMinutes(for: item)
        let start: Date
        switch kind {
        case .snooze:
            let from = max(item.startAt ?? now, now)
            start = from.addingTimeInterval(30 * 60)
        case .tonight:
            let tonight = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
            start = tonight > now ? tonight : now.addingTimeInterval(30 * 60)
        case .tomorrow:
            let base = item.startAt ?? now
            start = calendar.date(byAdding: .day, value: 1, to: base) ?? base
        }
        return try update(
            item: item,
            title: item.title,
            day: start,
            startHour: calendar.component(.hour, from: start),
            startMinute: calendar.component(.minute, from: start),
            durationMinutes: duration
        )
    }

    private func durationMinutes(for item: TodayTimelineItem) -> Int {
        let calendar = clock.calendar
        if let start = item.startAt, let end = item.endAt {
            return max(calendar.dateComponents([.minute], from: start, to: end).minute ?? 30, 5)
        }
        if let taskID = item.planTaskID, let task = repository.planTask(id: taskID) {
            return max(task.estimatedDurationMinutes, 5)
        }
        return 30
    }

    private func updateItem(
        item: TodayTimelineItem,
        title: String,
        day: Date,
        startHour: Int?,
        startMinute: Int?,
        durationMinutes: Int
    ) throws -> CaptureConfirmation {
        let calendar = clock.calendar
        var startAt: Date?
        var endAt: Date?
        if let startHour {
            startAt = calendar.date(bySettingHour: startHour, minute: startMinute ?? 0, second: 0, of: day)
            if let startAt {
                endAt = calendar.date(byAdding: .minute, value: max(durationMinutes, 1), to: startAt)
            }
        }
        if let startAt, let endAt, endAt <= startAt {
            throw CaptureError.invalidTimeRange
        }

        if let exceptionID = item.exceptionID, let exception = repository.exception(id: exceptionID) {
            guard let startAt, let endAt else { throw CaptureError.invalidTimeRange }
            try repository.updateException(exception, title: title, startAt: startAt, endAt: endAt)
            let warning = conflictMessage(
                startAt: startAt,
                endAt: endAt,
                ignoring: nil,
                ignoringExceptionID: exceptionID
            )
            return CaptureConfirmation(title: title, summary: "Updated \(title)", conflictWarning: warning)
        }

        let warning = conflictMessage(startAt: startAt, endAt: endAt, ignoring: item.timeBlockID)

        if let activityID = item.activityID, let activity = repository.activity(id: activityID) {
            repository.updateActivity(activity, title: title)
        }
        if let taskID = item.planTaskID, let task = repository.planTask(id: taskID) {
            repository.updatePlanTask(
                task,
                title: title,
                durationMinutes: max(durationMinutes, 1),
                deadline: task.deadline,
                preferredStartAt: startAt,
                priority: task.priority
            )
        }

        if let startAt, let endAt {
            if let blockID = item.timeBlockID, let block = repository.timeBlock(id: blockID) {
                try repository.updateTimeBlock(
                    block,
                    startAt: startAt,
                    endAt: endAt,
                    reason: "Edited manually",
                    provenance: nil
                )
            } else if let activityID = item.activityID {
                _ = try repository.createTimeBlock(TimeBlockDraft(
                    startAt: startAt,
                    endAt: endAt,
                    kind: .commitment,
                    activityID: activityID,
                    isLocked: true
                ))
            } else if let taskID = item.planTaskID {
                _ = try repository.createTimeBlock(TimeBlockDraft(
                    startAt: startAt,
                    endAt: endAt,
                    kind: .task,
                    planTaskID: taskID
                ))
            }
        } else if let blockID = item.timeBlockID, let block = repository.timeBlock(id: blockID) {
            repository.softDeleteScheduleRecord(block)
        }

        return CaptureConfirmation(
            title: title,
            summary: "Updated \(title)",
            conflictWarning: warning
        )
    }

    private func conflictMessage(startAt: Date?, endAt: Date?, ignoring blockID: UUID?, ignoringExceptionID: UUID? = nil) -> String? {
        guard let startAt, let endAt else { return nil }
        let interval = DateInterval(start: startAt, end: endAt)
        let overlappingBlocks = repository.fetchTimeBlocks(overlapping: interval)
            .filter { $0.id != blockID }
        let overlappingExceptions = repository.fetchExceptions(overlapping: interval)
            .filter { $0.id != ignoringExceptionID }
        guard !overlappingBlocks.isEmpty || !overlappingExceptions.isEmpty else { return nil }
        return "This overlaps another block. It was still saved; nothing else was moved."
    }

    private func summary(for draft: CaptureDraft, kind: String) -> String {
        var parts = [kind]
        parts.append(dayLabel(draft.day))
        if let hour = draft.startHour {
            let minute = draft.startMinute ?? 0
            if let time = clock.calendar.date(from: DateComponents(
                calendar: clock.calendar,
                hour: hour,
                minute: minute
            )) {
                parts.append(time.formatted(date: .omitted, time: .shortened))
            }
        }
        if let duration = draft.durationMinutes {
            parts.append("\(duration) min")
        }
        return parts.joined(separator: " · ")
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = clock.calendar
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
