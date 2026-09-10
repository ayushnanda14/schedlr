import Foundation

enum DayScopedFlag {
    private static func storageKey(_ key: String, on date: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date).timeIntervalSince1970
        return "anchor.dayflag.\(key).\(Int(day))"
    }

    static func isOn(_ key: String, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(key, on: date, calendar: calendar))
    }

    static func set(_ key: String, _ value: Bool, on date: Date = Date(), calendar: Calendar = .current) {
        UserDefaults.standard.set(value, forKey: storageKey(key, on: date, calendar: calendar))
    }
}
