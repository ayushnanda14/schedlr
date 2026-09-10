import Foundation
import SwiftData

@MainActor
enum WorkoutProgression {
    static func lastSets(
        for exerciseName: String,
        in sessions: [WorkoutSession],
        excludingToday: Bool = true,
        calendar: Calendar = .current
    ) -> [SetLog] {
        let matching = sessions
            .filter { session in
                if session.isDeleted { return false }
                if excludingToday, calendar.isDateInToday(session.date) { return false }
                return session.setLogs.contains { !$0.isDeleted && $0.exerciseName == exerciseName }
            }
            .sorted { $0.date > $1.date }

        guard let last = matching.first else { return [] }
        return last.setLogs
            .filter { !$0.isDeleted && $0.exerciseName == exerciseName }
            .sorted { $0.setNumber < $1.setNumber }
    }

    static func todaySets(
        for exerciseName: String,
        in session: WorkoutSession?
    ) -> [SetLog] {
        guard let session else { return [] }
        return session.setLogs
            .filter { !$0.isDeleted && $0.exerciseName == exerciseName }
            .sorted { $0.setNumber < $1.setNumber }
    }

    /// Double progression: last session hit the top of the rep range on every logged set.
    static func isReadyToIncreaseWeight(exercise: Exercise, lastSets: [SetLog]) -> Bool {
        guard exercise.isRepBased, lastSets.count >= exercise.targetSetCount else { return false }
        return lastSets.allSatisfy { $0.reps >= exercise.repRangeHigh }
    }

    static func formattedSets(_ sets: [SetLog], isRepBased: Bool) -> String {
        guard !sets.isEmpty else { return "No previous log" }
        return sets.map { set in
            if isRepBased {
                let weight = set.weightKg == floor(set.weightKg)
                    ? String(format: "%.0f", set.weightKg)
                    : String(format: "%.1f", set.weightKg)
                return "\(weight) kg × \(set.reps)"
            }
            return set.reps > 0 ? "\(set.reps)s" : "Set \(set.setNumber)"
        }
        .joined(separator: "  ·  ")
    }

    static func lastDeloadDate(in sessions: [WorkoutSession]) -> Date? {
        sessions
            .filter { !$0.isDeleted }
            .filter { session in
                session.isDeload || (session.notes?.localizedCaseInsensitiveContains("deload") ?? false)
            }
            .map(\.date)
            .max()
    }

    static func shouldNudgeDeload(sessions: [WorkoutSession], calendar: Calendar = .current) -> Bool {
        let sixWeeks: TimeInterval = 42 * 24 * 60 * 60
        if let lastDeload = lastDeloadDate(in: sessions) {
            return Date().timeIntervalSince(lastDeload) >= sixWeeks
        }
        guard let oldest = sessions.map(\.date).min() else { return false }
        return Date().timeIntervalSince(oldest) >= sixWeeks
    }

    static func todaySession(
        splitDay: SplitDay,
        sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> WorkoutSession? {
        sessions.first { !$0.isDeleted && calendar.isDateInToday($0.date) && $0.splitDay == splitDay }
    }
}
