import Foundation

enum DurationFormatting {
    static let presets = [15, 30, 45, 60, 90, 120, 180, 240, 360, 480, 600, 720]
    static let minimumMinutes = 5
    static let maximumMinutes = 18 * 60

    static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, minimumMinutes), maximumMinutes)
    }

    static func string(_ minutes: Int) -> String {
        let value = clamp(minutes)
        let hours = value / 60
        let remainder = value % 60
        if hours == 0 { return "\(remainder) min" }
        if remainder == 0 { return hours == 1 ? "1 h" : "\(hours) h" }
        return "\(hours) h \(remainder) min"
    }
}
