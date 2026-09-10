import Foundation

extension Calendar {
    func isSameDay(_ date1: Date?, _ date2: Date) -> Bool {
        guard let date1 else { return false }
        return isDate(date1, inSameDayAs: date2)
    }

    var currentWeekday: Int {
        component(.weekday, from: Date())
    }

    func daysBetween(_ start: Date, and end: Date) -> Int {
        let startDay = startOfDay(for: start)
        let endDay = startOfDay(for: end)
        return dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}

extension Date {
    func formattedDayName() -> String {
        formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "en_US")))
    }
}
