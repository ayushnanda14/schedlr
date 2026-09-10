import Foundation

enum DayScopedFlag {
    private static let prefix = "anchor.dayflag."

    private static func storageKey(_ key: String, on date: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date).timeIntervalSince1970
        return "\(prefix)\(key).\(Int(day))"
    }

    static func isOn(_ key: String, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(key, on: date, calendar: calendar))
    }

    static func set(
        _ key: String,
        _ value: Bool,
        on date: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(value, forKey: storageKey(key, on: date, calendar: calendar))
    }

    static func parse(_ storageKey: String) -> (key: String, day: Date)? {
        guard storageKey.hasPrefix(prefix) else { return nil }
        let rest = String(storageKey.dropFirst(prefix.count))
        guard let lastDot = rest.lastIndex(of: ".") else { return nil }
        let timestampString = String(rest[rest.index(after: lastDot)...])
        let flagKey = String(rest[..<lastDot])
        guard let interval = TimeInterval(timestampString), !flagKey.isEmpty else { return nil }
        return (flagKey, Date(timeIntervalSince1970: interval))
    }

    static func enabledFlags(
        in defaults: UserDefaults = .standard,
        knownKeys: Set<String>
    ) -> [(key: String, day: Date)] {
        defaults.dictionaryRepresentation().compactMap { storageKey, value in
            guard let parsed = parse(storageKey), knownKeys.contains(parsed.key) else { return nil }
            let isOn: Bool
            if let bool = value as? Bool {
                isOn = bool
            } else if let number = value as? NSNumber {
                isOn = number.boolValue
            } else {
                return nil
            }
            guard isOn else { return nil }
            return parsed
        }
    }
}

