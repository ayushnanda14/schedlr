import SwiftUI

struct HistoryView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @State private var filter: HistoryFilter = .all

    private var entries: [HistoryEntry] {
        store.fetchHistory(filter: filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heatmap
                filterChips
                if entries.isEmpty {
                    Text("Nothing logged yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            historyRow(entry)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 12 weeks")
                .font(.headline)
            ConsistencyHeatmap(counts: store.heatmapCounts(weeks: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { chip in
                    Button {
                        filter = chip
                    } label: {
                        Text(chip.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(filter == chip ? Color.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(filter == chip ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ entry: HistoryEntry) -> some View {
        if let sessionID = entry.workoutSessionID, let session = store.workoutSession(id: sessionID) {
            NavigationLink {
                WorkoutHistoryDetailView(session: session)
            } label: {
                HistoryRowLabel(entry: entry)
            }
            .buttonStyle(.plain)
        } else if let taskID = entry.periodicTaskID {
            NavigationLink {
                PeriodicTaskHistoryDetailView(
                    title: entry.title,
                    dates: store.completionDates(forTaskID: taskID)
                )
            } label: {
                HistoryRowLabel(entry: entry)
            }
            .buttonStyle(.plain)
        } else {
            HistoryRowLabel(entry: entry)
        }
    }
}

private struct HistoryRowLabel: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.systemImage)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ConsistencyHeatmap: View {
    let counts: [Date: Int]

    private let weeks = 12
    private let calendar = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let date = dateFor(week: week, weekday: weekday)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(fill(for: date))
                            .frame(width: 11, height: 11)
                    }
                }
            }
        }
    }

    private func dateFor(week: Int, weekday: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekdayToday = calendar.component(.weekday, from: today)
        let thisWeekStart = calendar.date(byAdding: .day, value: -(weekdayToday - 1), to: today) ?? today
        let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart) ?? today
        return calendar.date(byAdding: .day, value: week * 7 + weekday, to: gridStart) ?? today
    }

    private func fill(for date: Date) -> Color {
        if date > Date() { return Color(.tertiarySystemFill).opacity(0.3) }
        let count = counts[calendar.startOfDay(for: date)] ?? 0
        switch count {
        case 0: return Color(.tertiarySystemFill)
        case 1: return Color.accentColor.opacity(0.28)
        case 2, 3: return Color.accentColor.opacity(0.55)
        default: return Color.accentColor.opacity(0.85)
        }
    }
}

struct WorkoutHistoryDetailView: View {
    let session: WorkoutSession

    private var sets: [SetLog] {
        session.setLogs.filter { !$0.isDeleted }.sorted {
            if $0.exerciseName == $1.exerciseName { return $0.setNumber < $1.setNumber }
            return $0.exerciseName < $1.exerciseName
        }
    }

    var body: some View {
        List {
            Section(session.splitDay.displayName) {
                ForEach(sets, id: \.persistentModelID) { set in
                    HStack {
                        Text("\(set.exerciseName)  ·  set \(set.setNumber)")
                        Spacer()
                        Text("\(Int(set.weightKg)) kg × \(set.reps)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PeriodicTaskHistoryDetailView: View {
    let title: String
    let dates: [Date]

    var body: some View {
        List {
            if dates.isEmpty {
                Text("No completions logged.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(dates, id: \.self) { date in
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
