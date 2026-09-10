import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var splitDayRaw: String
    var targetSetCount: Int
    var repRangeLow: Int
    var repRangeHigh: Int
    var orderIndex: Int
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.notSynced.rawValue

    var splitDay: SplitDay {
        get { SplitDay(rawValue: splitDayRaw) ?? .rest }
        set { splitDayRaw = newValue.rawValue }
    }

    init(
        name: String,
        splitDay: SplitDay,
        targetSetCount: Int,
        repRangeLow: Int,
        repRangeHigh: Int,
        orderIndex: Int
    ) {
        self.name = name
        self.splitDayRaw = splitDay.rawValue
        self.targetSetCount = targetSetCount
        self.repRangeLow = repRangeLow
        self.repRangeHigh = repRangeHigh
        self.orderIndex = orderIndex
    }

    var isRepBased: Bool { repRangeHigh > 0 }

    var targetLabel: String {
        if isRepBased {
            if repRangeLow == repRangeHigh {
                return "\(targetSetCount)×\(repRangeLow)"
            }
            return "\(targetSetCount)×\(repRangeLow)–\(repRangeHigh)"
        }
        return "\(targetSetCount) sets"
    }
}

extension Exercise: SyncableRecord {}
