import Foundation
import SwiftData

@MainActor
enum SeedData {
    static func seedIfNeeded(context: ModelContext) throws {
        if try context.fetchCount(FetchDescriptor<Exercise>()) == 0 {
            seedExercises(context: context)
            seedGymSchedule(context: context)
            seedPeriodicTasks(context: context)
            seedDailyChecklist(context: context)
        }

        if try context.fetchCount(FetchDescriptor<NotificationPreferences>()) == 0 {
            context.insert(NotificationPreferences())
        }

        backfillPhase5(context: context)
        try context.save()
    }

    static func backfillPhase5(context: ModelContext) {
        uniquifyAllRecordIDs(context: context)
        backfillChecklistEvents(context: context)
        backfillPeriodicTaskEvents(context: context)
    }

    /// SwiftData applies one default UUID to every migrated row. Give each row a unique id.
    private static func uniquifyAllRecordIDs(context: ModelContext) {
        uniquifyIDs((try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<SetLog>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<DailyChecklistItem>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<SkincareNightLog>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<GymScheduleDay>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<NotificationPreferences>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<ChecklistCompletionEvent>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<NotificationEvent>())) ?? [])
        uniquifyIDs((try? context.fetch(FetchDescriptor<ActionEvent>())) ?? [])
    }

    private static func uniquifyIDs(_ records: [any SyncableRecord]) {
        var seen = Set<UUID>()
        for record in records {
            if seen.contains(record.id) {
                record.id = UUID()
                record.markDirty()
            }
            seen.insert(record.id)
        }
    }

    private static func backfillChecklistEvents(context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<DailyChecklistItem>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<ChecklistCompletionEvent>())) ?? []
        for item in items where !item.isDeleted {
            guard let last = item.lastCompletedDate else { continue }
            let hasEvent = events.contains { !$0.isDeleted && $0.checklistItemID == item.id }
            guard !hasEvent else { continue }
            context.insert(ChecklistCompletionEvent(
                checklistItemID: item.id,
                completedAt: last,
                modeAtCompletion: .normal
            ))
        }
    }

    private static func backfillPeriodicTaskEvents(context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<PeriodicTask>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<PeriodicTaskCompletionEvent>())) ?? []
        for task in tasks where !task.isDeleted {
            guard let last = task.lastCompletedDate else { continue }
            let hasEvent = events.contains { !$0.isDeleted && $0.periodicTaskID == task.id }
            guard !hasEvent else { continue }
            context.insert(PeriodicTaskCompletionEvent(
                periodicTaskID: task.id,
                completedAt: last
            ))
        }
    }

    private static func seedExercises(context: ModelContext) {
        let exercises: [(String, SplitDay, Int, Int, Int, Int)] = [
            // Upper A
            ("Bench Press", .upperA, 3, 6, 10, 0),
            ("Barbell/DB Row", .upperA, 3, 8, 12, 1),
            ("Overhead Press", .upperA, 3, 8, 12, 2),
            ("Lat Pulldown", .upperA, 3, 8, 12, 3),
            ("Face Pull", .upperA, 3, 12, 15, 4),
            ("Biceps Curl", .upperA, 2, 12, 15, 5),
            ("Triceps Pushdown", .upperA, 2, 12, 15, 6),
            // Lower A
            ("Squat", .lowerA, 3, 6, 10, 0),
            ("Romanian Deadlift", .lowerA, 3, 8, 12, 1),
            ("Leg Press", .lowerA, 3, 10, 12, 2),
            ("Leg Curl", .lowerA, 3, 10, 12, 3),
            ("Standing Calf Raise", .lowerA, 3, 12, 15, 4),
            ("Plank", .lowerA, 3, 0, 0, 5),
            // Upper B
            ("Incline DB Press", .upperB, 3, 8, 12, 0),
            ("Seated Cable Row", .upperB, 3, 8, 12, 1),
            ("Lateral Raise", .upperB, 3, 12, 15, 2),
            ("Wide-Grip Pulldown", .upperB, 3, 8, 12, 3),
            ("Band Pull-Apart", .upperB, 3, 15, 20, 4),
            ("Biceps/Triceps Superset", .upperB, 2, 12, 15, 5),
            // Lower B
            ("Deadlift", .lowerB, 3, 5, 8, 0),
            ("Front Squat", .lowerB, 3, 8, 12, 1),
            ("Bulgarian Split Squat", .lowerB, 2, 10, 12, 2),
            ("Leg Extension", .lowerB, 2, 12, 15, 3),
            ("Seated Calf Raise", .lowerB, 3, 15, 15, 4),
            ("Dead Bug", .lowerB, 3, 0, 0, 5),
        ]

        for (name, split, sets, low, high, order) in exercises {
            context.insert(Exercise(
                name: name,
                splitDay: split,
                targetSetCount: sets,
                repRangeLow: low,
                repRangeHigh: high,
                orderIndex: order
            ))
        }
    }

    private static func seedGymSchedule(context: ModelContext) {
        // Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        let schedule: [(Int, SplitDay)] = [
            (2, .upperA),  // Mon
            (3, .lowerA),  // Tue
            (4, .rest),    // Wed
            (5, .upperB),  // Thu
            (6, .lowerB),  // Fri
            (7, .rest),    // Sat
            (1, .rest),    // Sun
        ]
        for (weekday, split) in schedule {
            context.insert(GymScheduleDay(weekday: weekday, splitDay: split))
        }
    }

    private static func seedPeriodicTasks(context: ModelContext) {
        let tasks: [(String, Int)] = [
            ("Clean room", 5),
            ("Do the dishes", 2),
            ("Cook or order food (plan tonight's dinner)", 1),
        ]
        for (title, cadence) in tasks {
            context.insert(PeriodicTask(
                title: title,
                cadenceDays: cadence,
                activeInModes: [.livingAlone],
                pausesDuringAway: true
            ))
        }
    }

    private static func seedDailyChecklist(context: ModelContext) {
        let normalAndAlone: [AppMode] = [.normal, .livingAlone]
        let allModes: [AppMode] = [.normal, .livingAlone, .away]

        let items: [(String, TaskCategory, [AppMode])] = [
            ("AM skincare", .skincareAM, normalAndAlone),
            ("Pre-workout snack", .gym, normalAndAlone),
            ("Gym session", .gym, normalAndAlone),
            ("Post-workout meal", .nutrition, normalAndAlone),
            ("Movement breaks (workday)", .posture, normalAndAlone),
            ("Hit protein target", .nutrition, allModes),
            ("PM skincare", .skincarePM, normalAndAlone),
            ("Posture routine", .posture, normalAndAlone),
            ("Sleep by target time", .sleep, allModes),
            ("Sunscreen", .skincareAM, [.away]),
        ]

        for (title, category, modes) in items {
            context.insert(DailyChecklistItem(
                title: title,
                category: category,
                applicableModes: modes
            ))
        }
    }
}
