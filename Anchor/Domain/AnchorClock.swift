import Foundation

/// Time is injected into planning services so schedule behavior remains deterministic in tests.
protocol AnchorClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemAnchorClock: AnchorClock {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var now: Date { Date() }
}

struct FixedAnchorClock: AnchorClock {
    let now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }
}
