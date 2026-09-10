import Foundation
import SwiftData

@Model
final class UserProfile {
    var weightKg: Double
    var heightCm: Double
    var age: Int
    var sexRaw: String
    var activityMultiplier: Double
    var currentModeRaw: String
    var lateNightModeActiveToday: Bool
    var lateNightActivatedOn: Date?
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var currentMode: AppMode {
        get { AppMode(rawValue: currentModeRaw) ?? .normal }
        set { currentModeRaw = newValue.rawValue }
    }

    init(
        weightKg: Double = 85,
        heightCm: Double = 179,
        age: Int = 25,
        sex: Sex = .male,
        activityMultiplier: Double = 1.4,
        currentMode: AppMode = .normal,
        lateNightModeActiveToday: Bool = false,
        lateNightActivatedOn: Date? = nil
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.sexRaw = sex.rawValue
        self.activityMultiplier = activityMultiplier
        self.currentModeRaw = currentMode.rawValue
        self.lateNightModeActiveToday = lateNightModeActiveToday
        self.lateNightActivatedOn = lateNightActivatedOn
    }

    func resetLateNightIfNeeded(calendar: Calendar = .current) {
        guard lateNightModeActiveToday else { return }
        guard let activatedOn = lateNightActivatedOn else {
            lateNightModeActiveToday = false
            return
        }
        if !calendar.isDateInToday(activatedOn) {
            lateNightModeActiveToday = false
            lateNightActivatedOn = nil
            markDirty()
        }
    }

    func activateLateNightMode() {
        lateNightModeActiveToday = true
        lateNightActivatedOn = Date()
        markDirty()
    }
}

extension UserProfile: SyncableRecord {}
