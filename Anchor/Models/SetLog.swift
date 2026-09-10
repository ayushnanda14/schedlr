import Foundation
import SwiftData

@Model
final class SetLog {
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var setNumber: Int
    var session: WorkoutSession?
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(
        exerciseName: String,
        weightKg: Double,
        reps: Int,
        setNumber: Int,
        session: WorkoutSession? = nil
    ) {
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.setNumber = setNumber
        self.session = session
    }
}

extension SetLog: SyncableRecord {}
