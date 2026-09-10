import Foundation
import SwiftData

@Model
final class NotificationPreferences {
    var gymEnabled: Bool = true
    var movementEnabled: Bool = true
    var bedtimeEnabled: Bool = true
    var periodicTasksEnabled: Bool = true
    var quietHoursEnabled: Bool = true
    var quietHoursStartHour: Int = 22
    var quietHoursStartMinute: Int = 0
    var quietHoursEndHour: Int = 6
    var quietHoursEndMinute: Int = 0
    var gymHour: Int = 7
    var gymMinute: Int = 0
    var bedtimeHour: Int = 22
    var bedtimeMinute: Int = 30
    var periodicTaskHour: Int = 8
    var periodicTaskMinute: Int = 0
    var movementStartHour: Int = 10
    var movementStartMinute: Int = 30
    var movementEndHour: Int = 18
    var movementEndMinute: Int = 30
    var batchLowPriority: Bool = true
    var maxPendingRequests: Int = 24
    var snoozeMinutes: Int = 30
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    init(
        gymEnabled: Bool = true,
        movementEnabled: Bool = true,
        bedtimeEnabled: Bool = true,
        periodicTasksEnabled: Bool = true,
        quietHoursEnabled: Bool = true,
        quietHoursStartHour: Int = 22,
        quietHoursStartMinute: Int = 0,
        quietHoursEndHour: Int = 6,
        quietHoursEndMinute: Int = 0,
        gymHour: Int = 7,
        gymMinute: Int = 0,
        bedtimeHour: Int = 22,
        bedtimeMinute: Int = 30,
        periodicTaskHour: Int = 8,
        periodicTaskMinute: Int = 0,
        movementStartHour: Int = 10,
        movementStartMinute: Int = 30,
        movementEndHour: Int = 18,
        movementEndMinute: Int = 30,
        batchLowPriority: Bool = true,
        maxPendingRequests: Int = 24,
        snoozeMinutes: Int = 30
    ) {
        self.gymEnabled = gymEnabled
        self.movementEnabled = movementEnabled
        self.bedtimeEnabled = bedtimeEnabled
        self.periodicTasksEnabled = periodicTasksEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStartHour = quietHoursStartHour
        self.quietHoursStartMinute = quietHoursStartMinute
        self.quietHoursEndHour = quietHoursEndHour
        self.quietHoursEndMinute = quietHoursEndMinute
        self.gymHour = gymHour
        self.gymMinute = gymMinute
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.periodicTaskHour = periodicTaskHour
        self.periodicTaskMinute = periodicTaskMinute
        self.movementStartHour = movementStartHour
        self.movementStartMinute = movementStartMinute
        self.movementEndHour = movementEndHour
        self.movementEndMinute = movementEndMinute
        self.batchLowPriority = batchLowPriority
        self.maxPendingRequests = maxPendingRequests
        self.snoozeMinutes = snoozeMinutes
    }

    var anyEnabled: Bool {
        gymEnabled || movementEnabled || bedtimeEnabled || periodicTasksEnabled
    }

    var snapshot: NotificationPreferenceSnapshot {
        NotificationPreferenceSnapshot(
            gymEnabled: gymEnabled,
            movementEnabled: movementEnabled,
            bedtimeEnabled: bedtimeEnabled,
            periodicTasksEnabled: periodicTasksEnabled,
            quietHoursEnabled: quietHoursEnabled,
            quietHoursStartHour: quietHoursStartHour,
            quietHoursStartMinute: quietHoursStartMinute,
            quietHoursEndHour: quietHoursEndHour,
            quietHoursEndMinute: quietHoursEndMinute,
            gymHour: gymHour,
            gymMinute: gymMinute,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            periodicTaskHour: periodicTaskHour,
            periodicTaskMinute: periodicTaskMinute,
            movementStartHour: movementStartHour,
            movementStartMinute: movementStartMinute,
            movementEndHour: movementEndHour,
            movementEndMinute: movementEndMinute,
            batchLowPriority: batchLowPriority,
            maxPendingRequests: max(1, maxPendingRequests),
            snoozeMinutes: max(5, snoozeMinutes)
        )
    }
}

extension NotificationPreferences: SyncableRecord {}
