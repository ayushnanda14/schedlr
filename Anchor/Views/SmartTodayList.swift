import SwiftUI

struct SmartTodayList: View {
    let profile: UserProfile
    let items: [DailyChecklistItem]
    let dueTasks: [PeriodicTask]
    let now: Date
    let onToggleItem: (DailyChecklistItem) -> Void
    let onMarkTask: (PeriodicTask) -> Void

    private var period: DayPeriod { DayPeriod.current(at: now) }
    private var groups: (morning: [DailyChecklistItem], day: [DailyChecklistItem], evening: [DailyChecklistItem]) {
        TodayGrouping.grouped(items, lateNight: profile.lateNightModeActiveToday)
    }

    private var windowItems: [DailyChecklistItem] {
        switch period {
        case .morning: return groups.morning
        case .day: return groups.day
        case .evening: return groups.evening
        }
    }

    private var primaryItem: DailyChecklistItem? {
        windowItems.first { !$0.isCompletedToday() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if profile.currentMode == .away {
                awayList
            } else {
                windowSection
                if !dueTasks.isEmpty {
                    houseSection
                }
                earlierSection
                laterSection
            }
        }
    }

    private var houseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Also today")
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(dueTasks, id: \.persistentModelID) { task in
                TaskCard(
                    icon: "house",
                    title: task.title,
                    subtitle: taskSubtitle(task),
                    isComplete: false,
                    prominence: task.isSeverelyOverdue ? .primary : .standard,
                    isSevere: task.isSeverelyOverdue
                ) {
                    onMarkTask(task)
                }
            }
        }
    }

    private var awayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.persistentModelID) { item in
                itemCard(item, prominence: item.isCompletedToday() ? .compact : .standard)
            }
        }
    }

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TodayGrouping.inWindow(period).rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let primaryItem {
                itemCard(primaryItem, prominence: .primary)
            }

            ForEach(windowItems.filter { $0.persistentModelID != primaryItem?.persistentModelID }, id: \.persistentModelID) { item in
                itemCard(item, prominence: item.isCompletedToday() ? .compact : .standard)
            }
        }
    }

    @ViewBuilder
    private var earlierSection: some View {
        let earlier = earlierBuckets
        if !earlier.isEmpty {
            DisclosureGroup("Done earlier") {
                VStack(spacing: 6) {
                    ForEach(earlier, id: \.persistentModelID) { item in
                        itemCard(item, prominence: .compact)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var laterSection: some View {
        let later = laterBuckets
        if !later.isEmpty {
            DisclosureGroup("Later") {
                VStack(spacing: 6) {
                    ForEach(later, id: \.persistentModelID) { item in
                        itemCard(item, prominence: .compact)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var earlierBuckets: [DailyChecklistItem] {
        switch period {
        case .morning:
            return []
        case .day:
            return groups.morning.filter { $0.isCompletedToday() }
        case .evening:
            return (groups.morning + groups.day).filter { $0.isCompletedToday() }
        }
    }

    private var laterBuckets: [DailyChecklistItem] {
        switch period {
        case .morning:
            return groups.day + groups.evening
        case .day:
            return groups.evening + groups.morning.filter { !$0.isCompletedToday() }
        case .evening:
            return (groups.morning + groups.day).filter { !$0.isCompletedToday() }
        }
    }

    private func itemCard(_ item: DailyChecklistItem, prominence: TaskCard.Prominence) -> some View {
        TaskCard(
            icon: ChecklistIcon.systemName(for: item),
            title: item.title,
            trailingText: item.streakCount > 0 ? "\(item.streakCount)" : nil,
            isComplete: item.isCompletedToday(),
            prominence: prominence
        ) {
            onToggleItem(item)
        }
    }

    private func taskSubtitle(_ task: PeriodicTask) -> String {
        if task.isSeverelyOverdue {
            return "\(task.daysOverdue) days overdue"
        }
        if let last = task.lastCompletedDate {
            let days = Calendar.current.daysBetween(last, and: Date())
            if days == 0 { return "Last done today" }
            if days == 1 { return "Last done yesterday" }
            return "Last done \(days) days ago"
        }
        return "Never done"
    }
}
