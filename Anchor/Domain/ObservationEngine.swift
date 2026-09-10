import Foundation

/// Deterministic thresholds over local dated facts. Observations are not preferences.
struct ObservationEngine {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func observe(facts: ObservationFacts, now: Date) -> [RoutineObservation] {
        [
            morningGym(facts.gymCompletions, now: now),
            eveningPressure(facts.eveningPressureAt, now: now),
            repeatedSnooze(snoozes: facts.snoozesAt, completions: facts.lowPriorityCompletionsAt, now: now)
        ].compactMap { $0 }
    }

    private func morningGym(_ dates: [Date], now: Date) -> RoutineObservation? {
        let inWindow = datesInLookback(dates, now: now)
        let uniqueDays = uniquedByDay(inWindow)
        guard uniqueDays.count >= SuggestionPolicy.minGymSamples else { return nil }
        guard isFresh(uniqueDays, now: now) else { return nil }

        let morning = uniqueDays.filter { calendar.component(.hour, from: $0) < SuggestionPolicy.morningHourExclusive }
        let evening = uniqueDays.filter { calendar.component(.hour, from: $0) >= SuggestionPolicy.eveningGymHour }
        let sampleCount = uniqueDays.count
        let supporting = morning.count
        let contrary = evening.count
        guard supporting >= SuggestionPolicy.minGymSamples else { return nil }
        guard supporting * 4 >= sampleCount * 3 else { return nil }
        guard contrary * 2 <= supporting else { return nil }

        let evidence = makeEvidence(supporting: supporting, contrary: contrary, sample: sampleCount, dates: uniqueDays)
        let confidence: ConfidenceBand
        if sampleCount >= 6, supporting * 5 >= sampleCount * 4, contrary == 0 {
            confidence = .high
        } else if sampleCount >= 5 || contrary == 0 {
            confidence = .moderate
        } else {
            confidence = .low
        }

        return RoutineObservation(
            kind: .morningGymConsistency,
            evidence: evidence,
            confidence: confidence,
            reason: SuggestionCopy.gymReason,
            confidenceCopy: SuggestionCopy.gymConfidence(supporting: supporting, sample: sampleCount)
        )
    }

    private func eveningPressure(_ dates: [Date], now: Date) -> RoutineObservation? {
        let inWindow = datesInLookback(dates, now: now)
        let uniqueDays = uniquedByDay(inWindow)
        guard uniqueDays.count >= SuggestionPolicy.minPressureDays else { return nil }
        guard isFresh(uniqueDays, now: now) else { return nil }

        let evidence = makeEvidence(
            supporting: uniqueDays.count,
            contrary: 0,
            sample: uniqueDays.count,
            dates: uniqueDays
        )
        let confidence: ConfidenceBand
        switch uniqueDays.count {
        case 0..<4: confidence = .low
        case 4, 5: confidence = .moderate
        default: confidence = .high
        }

        return RoutineObservation(
            kind: .eveningSchedulePressure,
            evidence: evidence,
            confidence: confidence,
            reason: SuggestionCopy.pressureReason,
            confidenceCopy: SuggestionCopy.pressureConfidence(days: uniqueDays.count)
        )
    }

    private func repeatedSnooze(snoozes: [Date], completions: [Date], now: Date) -> RoutineObservation? {
        let inWindow = datesInLookback(snoozes, now: now)
        guard inWindow.count >= SuggestionPolicy.minSnoozes else { return nil }
        guard isFresh(inWindow, now: now) else { return nil }

        let recentCompletions = datesInRecent(completions, now: now)
        guard recentCompletions.count * 2 < inWindow.count else { return nil }

        let evidence = makeEvidence(
            supporting: inWindow.count,
            contrary: recentCompletions.count,
            sample: inWindow.count,
            dates: inWindow
        )
        let confidence: ConfidenceBand
        switch inWindow.count {
        case 0..<7: confidence = .low
        case 7, 8, 9: confidence = .moderate
        default: confidence = .high
        }

        return RoutineObservation(
            kind: .repeatedSnooze,
            evidence: evidence,
            confidence: confidence,
            reason: SuggestionCopy.snoozeReason,
            confidenceCopy: SuggestionCopy.snoozeConfidence(count: inWindow.count)
        )
    }

    private func datesInLookback(_ dates: [Date], now: Date) -> [Date] {
        let start = windowStart(now: now, days: SuggestionPolicy.lookbackDays)
        return dates.filter { $0 >= start && $0 <= now }
    }

    private func datesInRecent(_ dates: [Date], now: Date) -> [Date] {
        let start = windowStart(now: now, days: SuggestionPolicy.recentDays)
        return dates.filter { $0 >= start && $0 <= now }
    }

    private func isFresh(_ dates: [Date], now: Date) -> Bool {
        guard let last = dates.max() else { return false }
        return last >= windowStart(now: now, days: SuggestionPolicy.recentDays)
    }

    private func windowStart(now: Date, days: Int) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
    }

    private func uniquedByDay(_ dates: [Date]) -> [Date] {
        var earliest: [Date: Date] = [:]
        for date in dates {
            let day = calendar.startOfDay(for: date)
            if let existing = earliest[day] {
                if date < existing {
                    earliest[day] = date
                }
            } else {
                earliest[day] = date
            }
        }
        return earliest.values.sorted()
    }

    private func makeEvidence(supporting: Int, contrary: Int, sample: Int, dates: [Date]) -> SuggestionEvidence {
        SuggestionEvidence(
            supportingCount: supporting,
            contraryCount: contrary,
            sampleCount: sample,
            windowDays: SuggestionPolicy.lookbackDays,
            lastSeenAt: dates.max(),
            firstSeenAt: dates.min()
        )
    }
}
