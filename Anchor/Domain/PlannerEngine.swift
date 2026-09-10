import Foundation

struct PlannerEngine {
    let calendar: Calendar
    let policy: PlanningPolicy

    init(calendar: Calendar = .current, policy: PlanningPolicy = .default) {
        self.calendar = calendar
        self.policy = policy
    }

    func propose(now: Date, blocks: [PlanningBlock], extraOccupancy: [PlanningBlock] = []) -> PlanProposal? {
        let window = usableWindow(on: now)
        let immovable = blocks.filter(\.isImmovable) + extraOccupancy
        let movable = blocks.filter { !$0.isImmovable }
        let conflicting = movable.filter { candidate in
            immovable.contains { overlaps($0, candidate) }
        }
        .sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.startAt < rhs.startAt
        }

        guard !conflicting.isEmpty else { return nil }

        let triggerTitle = immovable.first { locked in
            conflicting.contains { overlaps(locked, $0) }
        }?.title

        var occupying = immovable + movable.filter { candidate in
            !conflicting.contains(where: { $0.id == candidate.id })
        }
        var changes: [PlanChange] = []

        for block in conflicting {
            let notBefore = immovable.filter { overlaps($0, block) }.map(\.endAt).max() ?? block.startAt
            if let slot = firstFit(
                duration: block.duration,
                occupying: occupying,
                window: window,
                notBefore: notBefore
            ) {
                let end = slot.addingTimeInterval(block.duration)
                occupying.append(PlanningBlock(
                    id: block.id,
                    title: block.title,
                    startAt: slot,
                    endAt: end,
                    isLocked: block.isLocked,
                    kind: block.kind,
                    priority: block.priority
                ))
                changes.append(PlanChange(
                    id: block.id,
                    title: block.title,
                    kind: .moved,
                    beforeStartAt: block.startAt,
                    beforeEndAt: block.endAt,
                    afterStartAt: slot,
                    afterEndAt: end
                ))
            } else if let deferred = deferredSlot(for: block, from: now) {
                changes.append(PlanChange(
                    id: block.id,
                    title: block.title,
                    kind: .deferred,
                    beforeStartAt: block.startAt,
                    beforeEndAt: block.endAt,
                    afterStartAt: deferred.start,
                    afterEndAt: deferred.end
                ))
            }
        }

        guard !changes.isEmpty else { return nil }
        return PlanProposal(
            id: UUID(),
            status: .pending,
            reason: ExplanationFormatter.reason(triggerTitle: triggerTitle, changes: changes),
            triggerTitle: triggerTitle,
            changes: changes
        )
    }

    private func usableWindow(on now: Date) -> DateInterval {
        let day = calendar.startOfDay(for: now)
        let start = calendar.date(bySettingHour: policy.dayStartHour, minute: 0, second: 0, of: day) ?? day
        let end = calendar.date(bySettingHour: policy.dayEndHour, minute: 0, second: 0, of: day)
            ?? calendar.date(byAdding: .day, value: 1, to: day)
            ?? now
        return DateInterval(start: max(start, now), end: max(end, now.addingTimeInterval(60)))
    }

    private func firstFit(
        duration: TimeInterval,
        occupying: [PlanningBlock],
        window: DateInterval,
        notBefore: Date
    ) -> Date? {
        let gap = TimeInterval(policy.gapMinutes * 60)
        let needed = duration + gap
        let gaps = freeIntervals(occupying: occupying, window: window)
        let preferred = gaps.filter { $0.end > notBefore }
        for interval in preferred {
            let start = max(interval.start, notBefore)
            if interval.end.timeIntervalSince(start) >= needed {
                return start
            }
        }
        for interval in gaps where interval.duration >= needed {
            return interval.start
        }
        return nil
    }

    private func freeIntervals(occupying: [PlanningBlock], window: DateInterval) -> [DateInterval] {
        let occupied = occupying
            .compactMap { block -> DateInterval? in
                let start = max(block.startAt, window.start)
                let end = min(block.endAt, window.end)
                guard end > start else { return nil }
                return DateInterval(start: start, end: end)
            }
            .sorted { $0.start < $1.start }

        var gaps: [DateInterval] = []
        var cursor = window.start
        for item in occupied {
            if item.start > cursor {
                gaps.append(DateInterval(start: cursor, end: item.start))
            }
            cursor = max(cursor, item.end)
        }
        if cursor < window.end {
            gaps.append(DateInterval(start: cursor, end: window.end))
        }
        return gaps
    }

    private func deferredSlot(for block: PlanningBlock, from now: Date) -> (start: Date, end: Date)? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let hour = calendar.component(.hour, from: block.startAt)
        let minute = calendar.component(.minute, from: block.startAt)
        let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
        return (start, start.addingTimeInterval(block.duration))
    }

    private func overlaps(_ lhs: PlanningBlock, _ rhs: PlanningBlock) -> Bool {
        lhs.startAt < rhs.endAt && lhs.endAt > rhs.startAt
    }
}
