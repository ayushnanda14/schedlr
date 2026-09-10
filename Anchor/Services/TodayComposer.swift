import Foundation

struct TodayComposer {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func compose(
        now: Date,
        activities: [Activity],
        planTasks: [PlanTask],
        timeBlocks: [TimeBlock],
        exceptions: [DayException] = []
    ) -> TodaySnapshot {
        let activityByID = Dictionary(activities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let taskByID = Dictionary(planTasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let timeline = (
            timeBlocks
                .filter { $0.startAt < $0.endAt }
                .map { block in
                    mapTimelineItem(block: block, activityByID: activityByID, taskByID: taskByID)
                }
            + exceptions.filter { $0.startAt < $0.endAt }.map(mapException)
        ).sorted { lhs, rhs in
            (lhs.startAt ?? .distantFuture) < (rhs.startAt ?? .distantFuture)
        }

        let current = timeline.first { item in
            guard let start = item.startAt, let end = item.endAt else { return false }
            return now >= start && now < end
        }
        let next = timeline.first { item in
            guard let start = item.startAt else { return false }
            return start > now
        }
        let laterTimed = timeline.filter { item in
            guard let start = item.startAt else { return false }
            if let next, let nextStart = next.startAt { return start > nextStart }
            return start > now
        }
        let scheduledTaskIDs = Set(timeBlocks.compactMap(\.planTaskID))
        let unscheduled = planTasks
            .filter { !scheduledTaskIDs.contains($0.id) }
            .prefix(6)
            .map(mapUnscheduledTask)

        return TodaySnapshot(
            now: now,
            current: current,
            next: next,
            later: Array(laterTimed.prefix(6)) + Array(unscheduled)
        )
    }

    private func mapTimelineItem(
        block: TimeBlock,
        activityByID: [UUID: Activity],
        taskByID: [UUID: PlanTask]
    ) -> TodayTimelineItem {
        let itemKind: TodayTimelineItem.Kind
        let title: String
        let typeLabel: String

        switch block.kind {
        case .commitment:
            itemKind = .fixedCommitment
            typeLabel = "Fixed"
            title = activityByID[block.activityID ?? UUID()]?.title ?? "Commitment"
        case .task:
            itemKind = .taskBlock
            typeLabel = "Task"
            title = taskByID[block.planTaskID ?? UUID()]?.title ?? "Scheduled task"
        case .buffer:
            itemKind = .buffer
            typeLabel = "Buffer"
            title = "Buffer"
        }

        let lockLabel = block.isLocked ? "Locked" : nil
        let range = "\(formatTime(block.startAt)) - \(formatTime(block.endAt))"
        let detailParts = [typeLabel, lockLabel, range].compactMap { $0 }

        return TodayTimelineItem(
            id: block.id,
            title: title,
            detail: detailParts.joined(separator: " · "),
            startAt: block.startAt,
            endAt: block.endAt,
            kind: itemKind,
            isLocked: block.isLocked,
            timeBlockID: block.id,
            activityID: block.activityID,
            planTaskID: block.planTaskID
        )
    }

    private func mapException(_ exception: DayException) -> TodayTimelineItem {
        TodayTimelineItem(
            id: exception.id,
            title: exception.title,
            detail: "Exception · \(exception.kind.displayName) · \(formatTime(exception.startAt)) - \(formatTime(exception.endAt))",
            startAt: exception.startAt,
            endAt: exception.endAt,
            kind: .dayException,
            isLocked: true,
            exceptionID: exception.id
        )
    }

    private func mapUnscheduledTask(_ task: PlanTask) -> TodayTimelineItem {
        TodayTimelineItem(
            id: task.id,
            title: task.title,
            detail: "Task · Unscheduled · \(task.estimatedDurationMinutes) min",
            startAt: nil,
            endAt: nil,
            kind: .taskBlock,
            isLocked: false,
            planTaskID: task.id
        )
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
