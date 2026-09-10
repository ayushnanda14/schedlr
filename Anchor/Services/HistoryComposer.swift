import Foundation

struct HistoryComposer {
    func compose(_ facts: [HistoryEntry], filter: HistoryFilter) -> [HistoryEntry] {
        facts
            .filter { filter == .all || $0.filter == filter }
            .sorted { $0.date > $1.date }
    }

    func context(for change: ScheduleChangeKind, beforeStart: Date?, afterStart: Date?, calendar: Calendar) -> HistoryEventContext? {
        switch change {
        case .created:
            return .scheduled
        case .moved:
            if let beforeStart, let afterStart, !calendar.isDate(beforeStart, inSameDayAs: afterStart), afterStart > beforeStart {
                return .deferred
            }
            return .moved
        case .resized:
            return .moved
        case .cancelled:
            return .deferred
        case .completed:
            return .completed
        case .locked, .unlocked, .restored:
            return nil
        }
    }

    func detail(context: HistoryEventContext, supporting: String) -> String {
        let trimmed = supporting.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return context.displayName }
        if trimmed.localizedCaseInsensitiveContains(context.displayName) {
            return trimmed
        }
        return "\(context.displayName) · \(trimmed)"
    }
}
