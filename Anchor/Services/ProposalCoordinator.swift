import Foundation

@MainActor
struct ProposalCoordinator {
    let repository: any ScheduleRepository
    let clock: any AnchorClock
    let engine: PlannerEngine

    init(repository: any ScheduleRepository, clock: any AnchorClock) {
        self.repository = repository
        self.clock = clock
        self.engine = PlannerEngine(calendar: clock.calendar)
    }

    func makeProposal(now: Date) -> PlanProposal? {
        let calendar = clock.calendar
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let activities = Dictionary(
            repository.fetchActivities().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let tasks = Dictionary(
            repository.fetchPlanTasks(includeClosed: false).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let dayInterval = DateInterval(start: start, end: end)
        let blocks = repository.fetchTimeBlocks(overlapping: dayInterval).map { block in
            let title: String
            let priority: PlanTaskPriority
            if let activityID = block.activityID, let activity = activities[activityID] {
                title = activity.title
                priority = .normal
            } else if let taskID = block.planTaskID, let task = tasks[taskID] {
                title = task.title
                priority = task.priority
            } else {
                title = block.kind == .commitment ? "Commitment" : "Task"
                priority = .normal
            }
            return PlanningBlock(
                id: block.id,
                title: title,
                startAt: block.startAt,
                endAt: block.endAt,
                isLocked: block.isLocked || block.kind == .commitment,
                kind: block.kind,
                priority: priority
            )
        }
        let calculator = AvailabilityCalculator(calendar: calendar)
        let exceptionBlocks = repository.fetchExceptions(overlapping: dayInterval).map { exception in
            PlanningBlock(
                id: exception.id,
                title: exception.title,
                startAt: exception.startAt,
                endAt: exception.endAt,
                isLocked: true,
                kind: .commitment,
                priority: .urgent
            )
        }
        let constraintBlocks = repository.fetchConstraints(overlapping: dayInterval).filter(\.isHard).map { constraint in
            PlanningBlock(
                id: constraint.id,
                title: constraint.title,
                startAt: constraint.startAt,
                endAt: constraint.endAt,
                isLocked: true,
                kind: .commitment,
                priority: .urgent
            )
        }
        let occupancy = calculator.occupancyBlocks(now: now, exceptions: exceptionBlocks, constraints: constraintBlocks)
            + calculator.paddedImmovable(blocks.filter(\.isImmovable) + exceptionBlocks)
        return engine.propose(now: now, blocks: blocks, extraOccupancy: occupancy)
    }

    func currentPressure(now: Date) -> SchedulePressure {
        let calendar = clock.calendar
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let dayInterval = DateInterval(start: start, end: end)
        let tasks = repository.fetchPlanTasks(includeClosed: false)
        let scheduledIDs = Set(repository.fetchTimeBlocks(overlapping: dayInterval).compactMap(\.planTaskID))
        let unscheduled = tasks.filter { !scheduledIDs.contains($0.id) }
        let activities = Dictionary(repository.fetchActivities().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let taskByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let blocks = repository.fetchTimeBlocks(overlapping: dayInterval).map { block -> PlanningBlock in
            let title: String
            let priority: PlanTaskPriority
            if let activityID = block.activityID, let activity = activities[activityID] {
                title = activity.title
                priority = .normal
            } else if let taskID = block.planTaskID, let task = taskByID[taskID] {
                title = task.title
                priority = task.priority
            } else {
                title = "Item"
                priority = .normal
            }
            return PlanningBlock(
                id: block.id,
                title: title,
                startAt: block.startAt,
                endAt: block.endAt,
                isLocked: block.isLocked || block.kind == .commitment,
                kind: block.kind,
                priority: priority
            )
        }
        let calculator = AvailabilityCalculator(calendar: calendar)
        let exceptionBlocks = repository.fetchExceptions(overlapping: dayInterval).map {
            PlanningBlock(id: $0.id, title: $0.title, startAt: $0.startAt, endAt: $0.endAt, isLocked: true, kind: .commitment, priority: .urgent)
        }
        let constraintBlocks = repository.fetchConstraints(overlapping: dayInterval).filter(\.isHard).map {
            PlanningBlock(id: $0.id, title: $0.title, startAt: $0.startAt, endAt: $0.endAt, isLocked: true, kind: .commitment, priority: .urgent)
        }
        let occupancy = calculator.occupancyBlocks(now: now, exceptions: exceptionBlocks, constraints: constraintBlocks)
            + calculator.paddedImmovable(blocks.filter(\.isImmovable) + exceptionBlocks)
        return calculator.pressure(
            now: now,
            blocks: blocks,
            unscheduledFlexibleMinutes: unscheduled.reduce(0) { $0 + $1.estimatedDurationMinutes },
            unscheduledFlexibleCount: unscheduled.count,
            extraOccupancy: occupancy
        )
    }

    func apply(_ proposal: PlanProposal) throws -> PlanProposal {
        for change in proposal.changes {
            guard let block = repository.timeBlock(id: change.id),
                  let start = change.afterStartAt,
                  let end = change.afterEndAt else { continue }
            try repository.updateTimeBlock(
                block,
                startAt: start,
                endAt: end,
                reason: change.kind == .deferred ? "Deferred by proposal" : "Accepted proposal",
                provenance: .acceptedProposal
            )
        }
        var applied = proposal
        applied.status = .accepted
        return applied
    }

    func undo(_ proposal: PlanProposal) throws -> PlanProposal {
        for change in proposal.changes {
            guard let block = repository.timeBlock(id: change.id) else { continue }
            try repository.updateTimeBlock(
                block,
                startAt: change.beforeStartAt,
                endAt: change.beforeEndAt,
                reason: "Undo proposal",
                provenance: .manual
            )
        }
        var undone = proposal
        undone.status = .undone
        return undone
    }
}
