import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    var weightKg: Double
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(date: Date = Date(), weightKg: Double) {
        self.date = date
        self.weightKg = weightKg
    }
}

extension WeightEntry: SyncableRecord {}
