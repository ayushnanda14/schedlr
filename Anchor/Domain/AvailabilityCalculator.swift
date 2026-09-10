import Foundation

struct AvailabilityCalculator {
    let calendar: Calendar
    let policy: PlanningPolicy

    init(calendar: Calendar = .current, policy: PlanningPolicy = .default) {
        self.calendar = calendar
        self.policy = policy
    }

    func window(on now: Date) -> DateInterval {
        let day = calendar.startOfDay(for: now)
        let start = calendar.date(bySettingHour: policy.dayStartHour, minute: 0, second: 0, of: day) ?? day
        let end = calendar.date(bySettingHour: policy.dayEndHour, minute: 0, second: 0, of: day)
            ?? calendar.date(byAdding: .day, value: 1, to: day)
            ?? now
        return DateInterval(start: max(start, now), end: max(end, now.addingTimeInterval(60)))
    }

    func occupancyBlocks(
        now: Date,
        exceptions: [PlanningBlock],
        constraints: [PlanningBlock]
    ) -> [PlanningBlock] {
        let window = window(on: now)
        var intervals: [(title: String, interval: DateInterval)] = []
        intervals.append(contentsOf: exceptions.map { ("Exception · \($0.title)", DateInterval(start: $0.startAt, end: $0.endAt)) })
        intervals.append(contentsOf: constraints.map { ($0.title, DateInterval(start: $0.startAt, end: $0.endAt)) })
        intervals.append(contentsOf: protectedBuffers(in: window).map { ("Quiet hours", $0) })

        return intervals.compactMap { item in
            let clipped = clip(item.interval, to: window)
            guard clipped.duration > 0 else { return nil }
            return PlanningBlock(
                id: UUID(),
                title: item.title,
                startAt: clipped.start,
                endAt: clipped.end,
                isLocked: true,
                kind: .commitment,
                priority: .urgent
            )
        }
    }

    func paddedImmovable(_ blocks: [PlanningBlock]) -> [PlanningBlock] {
        let padding = TimeInterval(policy.buffer.minimumGapMinutes * 60)
        return blocks.map { block in
            var padded = block
            padded.endAt = block.endAt.addingTimeInterval(padding)
            return padded
        }
    }

    func pressure(
        now: Date,
        blocks: [PlanningBlock],
        unscheduledFlexibleMinutes: Int,
        unscheduledFlexibleCount: Int,
        extraOccupancy: [PlanningBlock]
    ) -> SchedulePressure {
        let window = window(on: now)
        let immovable = blocks.filter(\.isImmovable)
        let movable = blocks.filter { !$0.isImmovable }
        let hard = Self.merge(
            (immovable + extraOccupancy).map { clip(DateInterval(start: $0.startAt, end: $0.endAt), to: window) }
        )
        let windowMinutes = max(Int(window.duration / 60), 0)
        let hardMinutes = Self.minutes(hard)
        let usable = max(windowMinutes - hardMinutes, 0)
        let fixed = Self.minutes(immovable.map { clip(DateInterval(start: $0.startAt, end: $0.endAt), to: window) })
        let locked = Self.minutes(
            blocks.filter(\.isLocked).map { clip(DateInterval(start: $0.startAt, end: $0.endAt), to: window) }
        )
        let flexibleScheduled = Self.minutes(
            movable.map { clip(DateInterval(start: $0.startAt, end: $0.endAt), to: window) }
        )
        let flexiblePlanned = flexibleScheduled + max(unscheduledFlexibleMinutes, 0)
        let flexibleCount = movable.count + max(unscheduledFlexibleCount, 0)
        let bufferMinutes = policy.buffer.minimumGapMinutes + policy.buffer.sleepBufferMinutes
        let remaining = usable - flexiblePlanned

        let state: SchedulePressureState
        if flexiblePlanned > usable {
            state = .oversubscribed
        } else if remaining < bufferMinutes, flexiblePlanned > 0 {
            state = .tight
        } else {
            state = .feasible
        }

        return SchedulePressure(
            fixedMinutes: fixed,
            lockedMinutes: locked,
            flexiblePlannedMinutes: flexiblePlanned,
            usableMinutes: usable,
            protectedBufferMinutes: bufferMinutes,
            flexibleItemCount: flexibleCount,
            state: state
        )
    }

    func protectedBuffers(in window: DateInterval) -> [DateInterval] {
        var intervals: [DateInterval] = []
        if let quietStart = calendar.date(
            bySettingHour: policy.buffer.quietHoursStartHour,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: window.start)
        ) {
            intervals.append(DateInterval(start: quietStart, end: window.end))
        }
        if policy.buffer.sleepBufferMinutes > 0 {
            let sleepStart = window.end.addingTimeInterval(TimeInterval(-policy.buffer.sleepBufferMinutes * 60))
            intervals.append(DateInterval(start: max(sleepStart, window.start), end: window.end))
        }
        return intervals.filter { $0.duration > 0 }
    }

    func clip(_ interval: DateInterval, to window: DateInterval) -> DateInterval {
        let start = max(interval.start, window.start)
        let end = min(interval.end, window.end)
        if end <= start {
            return DateInterval(start: start, duration: 0)
        }
        return DateInterval(start: start, end: end)
    }

    static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var result: [DateInterval] = []
        for interval in sorted {
            if let last = result.last, last.end >= interval.start {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }

    static func minutes(_ intervals: [DateInterval]) -> Int {
        Int(merge(intervals).reduce(0) { $0 + $1.duration } / 60)
    }
}
