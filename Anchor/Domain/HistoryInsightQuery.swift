import Foundation

/// Read-only aggregation over history facts. Views must not compute these summaries themselves.
struct HistoryInsightQuery {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        facts: [HistoryEntry],
        range: HistoryRange,
        filter: HistoryFilter,
        now: Date,
        cadence: [HistoryCadenceInput],
        workouts: [HistoryWorkoutSample],
        weights: [HistoryWeightSample],
        observations: [RoutineObservation]
    ) -> HistoryInsightSnapshot {
        let interval = range.interval(now: now, calendar: calendar)
        let inRange = facts.filter { interval.contains($0.date) }
        let entries = HistoryComposer().compose(inRange, filter: filter)
        let summaries = categorySummaries(inRange)
        return HistoryInsightSnapshot(
            range: range,
            interval: interval,
            filter: filter,
            entries: entries,
            categorySummaries: summaries,
            cadence: cadenceSummaries(cadence, now: now),
            workoutProgression: workoutProgression(workouts, interval: interval),
            schedule: scheduleSummary(inRange),
            reflections: reflections(
                observations: observations,
                weights: weights.filter { interval.contains($0.date) },
                scheduleFacts: inRange.filter { $0.filter == .schedule }
            ),
            emptyCopy: emptyCopy(allFacts: facts, entries: entries, filter: filter),
            heatmapActiveDays: heatmapActiveDays(facts)
        )
    }

    private func categorySummaries(_ facts: [HistoryEntry]) -> [HistoryCategorySummary] {
        let order: [HistoryFilter] = [.gym, .skincare, .periodicTasks, .schedule, .weight]
        return order.compactMap { filter in
            let count = facts.filter { $0.filter == filter }.count
            guard count > 0 else { return nil }
            let noun = count == 1 ? "log" : "logs"
            return HistoryCategorySummary(
                filter: filter,
                count: count,
                caption: "\(filter.displayName) · \(count) \(noun)"
            )
        }
    }

    private func cadenceSummaries(_ inputs: [HistoryCadenceInput], now: Date) -> [HistoryCadenceSummary] {
        inputs.compactMap { input in
            guard input.cadenceDays > 0 else { return nil }
            guard input.lastCompleted != nil || !input.datesInRange.isEmpty else { return nil }
            let times = input.datesInRange.count
            let timesCopy = times == 1 ? "1 time" : "\(times) times"
            var parts = ["\(timesCopy) in this window", "every \(input.cadenceDays) days"]
            if let last = input.lastCompleted {
                parts.append(lastDoneCopy(last, now: now))
            }
            return HistoryCadenceSummary(
                id: input.id,
                title: input.title,
                detail: parts.joined(separator: " · ")
            )
        }
        .sorted { $0.title < $1.title }
    }

    private func lastDoneCopy(_ date: Date, now: Date) -> String {
        let days = calendar.daysBetween(calendar.startOfDay(for: date), and: calendar.startOfDay(for: now))
        if days == 0 { return "last done today" }
        if days == 1 { return "last done yesterday" }
        return "last done \(days) days ago"
    }

    private func workoutProgression(
        _ samples: [HistoryWorkoutSample],
        interval: DateInterval
    ) -> [HistoryWorkoutProgression] {
        let inRange = samples.filter { interval.contains($0.date) }
        let names = Array(Set(inRange.map(\.exerciseName)))
        let ranked: [(Date, HistoryWorkoutProgression)] = names.compactMap { name in
            let sessions = sessionLifts(inRange.filter { $0.exerciseName == name })
            guard sessions.count >= 2 else { return nil }
            let last = sessions[sessions.count - 1]
            let previous = sessions[sessions.count - 2]
            let delta = last.weightKg - previous.weightKg
            let comparison: String
            if abs(delta) < 0.25 {
                comparison = "same top weight as the session before"
            } else if delta > 0 {
                comparison = "\(formatKg(delta)) more than the session before"
            } else {
                comparison = "\(formatKg(-delta)) less than the session before"
            }
            return (
                last.date,
                HistoryWorkoutProgression(
                    name: name,
                    detail: "Last \(formatLift(last)), \(comparison)."
                )
            )
        }
        return Array(ranked.sorted { $0.0 > $1.0 }.prefix(3).map(\.1))
    }

    private func sessionLifts(_ samples: [HistoryWorkoutSample]) -> [(date: Date, weightKg: Double, reps: Int)] {
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted().compactMap { day in
            guard let best = grouped[day]?.max(by: {
                if $0.weightKg != $1.weightKg { return $0.weightKg < $1.weightKg }
                return $0.reps < $1.reps
            }) else { return nil }
            return (day, best.weightKg, best.reps)
        }
    }

    private func scheduleSummary(_ facts: [HistoryEntry]) -> HistoryScheduleSummary? {
        let moved = facts.filter { $0.context == .moved }.count
        let deferred = facts.filter { $0.context == .deferred }.count
        let corrected = facts.filter { $0.context == .corrected }.count
        guard moved + deferred + corrected > 0 else { return nil }
        var parts: [String] = []
        if moved > 0 { parts.append(moved == 1 ? "1 moved" : "\(moved) moved") }
        if deferred > 0 { parts.append(deferred == 1 ? "1 deferred" : "\(deferred) deferred") }
        if corrected > 0 {
            parts.append(corrected == 1 ? "1 current-activity correction" : "\(corrected) current-activity corrections")
        }
        return HistoryScheduleSummary(
            moved: moved,
            deferred: deferred,
            corrected: corrected,
            caption: parts.joined(separator: " · ")
        )
    }

    private func reflections(
        observations: [RoutineObservation],
        weights: [HistoryWeightSample],
        scheduleFacts: [HistoryEntry]
    ) -> [HistoryReflection] {
        var items: [HistoryReflection] = observations.map { observation in
            HistoryReflection(
                id: observation.kind.rawValue,
                title: observation.kind.displayName,
                reason: observation.reason,
                confidenceCopy: "\(observation.confidence.displayName). \(observation.confidenceCopy)"
            )
        }

        if let weight = weightReflection(weights) {
            items.append(weight)
        }

        let corrections = scheduleFacts.filter { $0.context == .corrected }.count
        if corrections >= 2 {
            items.append(
                HistoryReflection(
                    id: "corrections",
                    title: "Current activity",
                    reason: "The current block was corrected \(corrections) times in this window.",
                    confidenceCopy: "Counted from local history, not a preference."
                )
            )
        }

        return Array(items.prefix(3))
    }

    private func weightReflection(_ weights: [HistoryWeightSample]) -> HistoryReflection? {
        let ordered = weights.sorted { $0.date < $1.date }
        guard ordered.count >= 2 else { return nil }
        let first = ordered[0].weightKg
        let last = ordered[ordered.count - 1].weightKg
        guard abs(last - first) >= 0.4 else { return nil }
        return HistoryReflection(
            id: "weight-trend",
            title: "Weight",
            reason: String(
                format: "Weight went from %.1f kg to %.1f kg across %d weigh-ins.",
                first,
                last,
                ordered.count
            ),
            confidenceCopy: "Shown because the change is large enough to notice, not as a goal."
        )
    }

    private func emptyCopy(allFacts: [HistoryEntry], entries: [HistoryEntry], filter: HistoryFilter) -> String {
        if allFacts.isEmpty {
            return "Nothing logged yet."
        }
        if entries.isEmpty, filter == .all {
            return "Nothing in this window."
        }
        if entries.isEmpty {
            return "No \(filter.displayName.lowercased()) events in this window."
        }
        return ""
    }

    private func heatmapActiveDays(_ facts: [HistoryEntry]) -> Int {
        Set(facts.map { calendar.startOfDay(for: $0.date) }).count
    }

    private func formatLift(_ lift: (date: Date, weightKg: Double, reps: Int)) -> String {
        "\(formatKg(lift.weightKg)) × \(lift.reps)"
    }

    private func formatKg(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f kg", value)
        }
        return String(format: "%.1f kg", value)
    }
}