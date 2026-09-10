import Foundation

enum DayPeriod {
    case morning
    case day
    case evening

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> DayPeriod {
        let hour = calendar.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 18 { return .day }
        return .evening
    }
}

enum TodayGrouping {
    enum Bucket: String {
        case morning = "Morning"
        case day = "Day"
        case evening = "Evening"
    }

    static func bucket(for item: DailyChecklistItem, lateNight: Bool) -> Bucket? {
        switch item.category {
        case .skincareAM:
            return .morning
        case .gym:
            return item.title.contains("Pre-workout") ? .morning : .day
        case .nutrition:
            return .day
        case .posture:
            if item.title.contains("Movement") { return .day }
            return lateNight ? nil : .evening
        case .skincarePM:
            return lateNight ? nil : .evening
        case .sleep:
            return .evening
        }
    }

    static func grouped(
        _ items: [DailyChecklistItem],
        lateNight: Bool
    ) -> (morning: [DailyChecklistItem], day: [DailyChecklistItem], evening: [DailyChecklistItem]) {
        var morning: [DailyChecklistItem] = []
        var day: [DailyChecklistItem] = []
        var evening: [DailyChecklistItem] = []
        for item in items {
            switch bucket(for: item, lateNight: lateNight) {
            case .morning: morning.append(item)
            case .day: day.append(item)
            case .evening: evening.append(item)
            case nil: break
            }
        }
        return (morning, day, evening)
    }

    static func inWindow(_ period: DayPeriod) -> Bucket {
        switch period {
        case .morning: return .morning
        case .day: return .day
        case .evening: return .evening
        }
    }
}
