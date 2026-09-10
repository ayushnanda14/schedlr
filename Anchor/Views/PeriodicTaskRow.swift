import SwiftUI

struct PeriodicTaskRow: View {
    let task: PeriodicTask
    var showsDueDate: Bool = false
    let onMarkDone: () -> Void

    var body: some View {
        TaskCard(
            icon: "house",
            title: task.title,
            subtitle: subtitle,
            isComplete: Calendar.current.isDateInToday(task.lastCompletedDate ?? .distantPast),
            prominence: task.isSeverelyOverdue ? .primary : .standard,
            isSevere: task.isSeverelyOverdue,
            action: onMarkDone
        )
    }

    private var subtitle: String {
        var parts: [String] = []
        if let last = task.lastCompletedDate {
            let days = Calendar.current.daysBetween(last, and: Date())
            if days == 0 { parts.append("Last done today") }
            else if days == 1 { parts.append("Last done yesterday") }
            else { parts.append("Last done \(days) days ago") }
        } else {
            parts.append("Never done")
        }
        if showsDueDate, let due = task.nextDueDate {
            parts.append("Due \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        if task.isSeverelyOverdue {
            parts.append("\(task.daysOverdue) days overdue")
        }
        return parts.joined(separator: " · ")
    }
}
