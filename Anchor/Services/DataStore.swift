import Foundation
import SwiftData

/// Local-only for now. A future `SyncedDataStore` can wrap `LocalSwiftDataStore`
/// and push/pull using `id` / `updatedAt` / `syncStatus` without changing views.
@MainActor
protocol DataStore: AnyObject {
    func fetchChecklistItems(mode: AppMode) -> [DailyChecklistItem]
    func logChecklistCompletion(itemID: UUID, mode: AppMode)
    func undoChecklistCompletion(itemID: UUID)
    func toggleChecklistItem(itemID: UUID, mode: AppMode)
    func fetchPeriodicTasks(mode: AppMode) -> [PeriodicTask]
    @discardableResult func logPeriodicTaskCompletion(taskID: UUID) -> CompletionWriteResult
    func undoPeriodicTaskCompletion(taskID: UUID)
    func fetchRoutineSteps(category: TaskCategory?) -> [RoutineStep]
    func isRoutineStepCompleteToday(stepID: UUID) -> Bool
    @discardableResult func logRoutineCompletion(stepID: UUID, on day: Date?) -> CompletionWriteResult
    func undoRoutineCompletion(stepID: UUID)
    func toggleRoutineStep(stepID: UUID)
    func ensureRoutineCatalog()
    func backfillRoutineCompletions(defaults: UserDefaults)
    @discardableResult func logActivityCompletion(item: TodayTimelineItem) -> CompletionWriteResult
    @discardableResult func logActivityCorrection(item: TodayTimelineItem, actual: CurrentActivityKind) -> CompletionWriteResult
    func undoActivityEvent(id: UUID)
    func completedTimeBlockIDs(on day: Date) -> Set<UUID>
    func currentActivityOverride(for item: TodayTimelineItem?) -> CurrentActivityOverride?
    func saveWeight(kg: Double, on date: Date, profile: UserProfile)
    func upsertSkincareNightLog(_ mutate: (SkincareNightLog) -> Void) -> SkincareNightLog
    func ensureWorkoutSession(splitDay: SplitDay, notes: String?) -> WorkoutSession
    func logSet(session: WorkoutSession, exerciseName: String, weightKg: Double, reps: Int, setNumber: Int)
    func updateWorkoutNotes(_ session: WorkoutSession, notes: String?)
    func markSessionDeload(_ session: WorkoutSession)
    func persist(_ record: any SyncableRecord)
    func fetchHistory(filter: HistoryFilter) -> [HistoryEntry]
    func historySnapshot(range: HistoryRange, filter: HistoryFilter) -> HistoryInsightSnapshot
    func heatmapCounts(weeks: Int) -> [Date: Int]
    func workoutSession(id: UUID) -> WorkoutSession?
    func periodicTask(id: UUID) -> PeriodicTask?
    func completionDates(forTaskID id: UUID) -> [Date]
}
