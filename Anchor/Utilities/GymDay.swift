import Foundation

enum GymDay {
    static func split(for date: Date = Date(), schedule: [GymScheduleDay]) -> SplitDay {
        let weekday = Calendar.current.component(.weekday, from: date)
        return schedule.first(where: { $0.weekday == weekday })?.splitDay ?? .rest
    }
}
