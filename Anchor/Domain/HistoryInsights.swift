import Foundation

struct HistoryEntry: Identifiable, Equatable, Sendable {
    var id: UUID
    var filter: HistoryFilter
    var date: Date
    var title: String
    var detail: String
    var systemImage: String
    var context: HistoryEventContext
    var workoutSessionID: UUID?
    var periodicTaskID: UUID?

    init(
        id: UUID,
        filter: HistoryFilter,
        date: Date,
        title: String,
        detail: String,
        systemImage: String,
        context: HistoryEventContext = .logged,
        workoutSessionID: UUID? = nil,
        periodicTaskID: UUID? = nil
    ) {
        self.id = id
        self.filter = filter
        self.date = date
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.context = context
        self.workoutSessionID = workoutSessionID
        self.periodicTaskID = periodicTaskID
    }
}

struct HistoryCadenceInput: Equatable, Sendable {
    var id: UUID
    var title: String
    var cadenceDays: Int
    var lastCompleted: Date?
    var datesInRange: [Date]
}

struct HistoryWorkoutSample: Equatable, Sendable {
    var exerciseName: String
    var date: Date
    var weightKg: Double
    var reps: Int
}

struct HistoryWeightSample: Equatable, Sendable {
    var date: Date
    var weightKg: Double
}

struct HistoryCategorySummary: Identifiable, Equatable, Sendable {
    var id: HistoryFilter { filter }
    var filter: HistoryFilter
    var count: Int
    var caption: String
}

struct HistoryCadenceSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var detail: String
}

struct HistoryWorkoutProgression: Identifiable, Equatable, Sendable {
    var id: String { name }
    var name: String
    var detail: String
}

struct HistoryScheduleSummary: Equatable, Sendable {
    var moved: Int
    var deferred: Int
    var corrected: Int
    var caption: String
}

struct HistoryReflection: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var reason: String
    var confidenceCopy: String
}

struct HistoryInsightSnapshot: Equatable, Sendable {
    var range: HistoryRange
    var interval: DateInterval
    var filter: HistoryFilter
    var entries: [HistoryEntry]
    var categorySummaries: [HistoryCategorySummary]
    var cadence: [HistoryCadenceSummary]
    var workoutProgression: [HistoryWorkoutProgression]
    var schedule: HistoryScheduleSummary?
    var reflections: [HistoryReflection]
    var emptyCopy: String
    var heatmapActiveDays: Int
}

enum AnchorAID {
    static let historyRoot = "history.root"
    static let historyRange = "history.range"
    static let historyHeatmap = "history.heatmap"
    static let historySummaries = "history.summaries"
    static let historyCadence = "history.cadence"
    static let historyWorkout = "history.workout"
    static let historySchedule = "history.schedule"
    static let historyReflections = "history.reflections"
    static let historyEmpty = "history.empty"
    static let historyFilterPrefix = "history.filter."
    static let todayAdd = "today.add"
    static let todayHistory = "today.history"
    static let nutritionSave = "nutrition.save"
}