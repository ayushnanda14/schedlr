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
                        .font(AnchorFont.subheadline)
                        .foregroundStyle(AnchorColor.textSecondary)
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
            .padding(16)
        }
        .background(AnchorScreenBackground())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AnchorColor.background, for: .navigationBar)
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 12 weeks")
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)
            ConsistencyHeatmap(counts: store.heatmapCounts(weeks: 12))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { chip in
                    Button {
                        filter = chip
                    } label: {
                        Text(chip.displayName)
                            .font(AnchorFont.captionEmphasized)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(filter == chip ? AnchorColor.brand : AnchorColor.surfaceMuted)
                            .foregroundStyle(filter == chip ? AnchorColor.onBrand : AnchorColor.textPrimary)
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
                .foregroundStyle(AnchorColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.textPrimary)
                Text(entry.detail)
                    .font(AnchorFont.caption)
                    .foregroundStyle(AnchorColor.textSecondary)
            }
            Spacer()
            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)
        }
        .padding(14)
        .anchorSurface(.raised)
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
        if date > Date() { return AnchorColor.surfaceMuted.opacity(0.45) }
        let count = counts[calendar.startOfDay(for: date)] ?? 0
        switch count {
        case 0: return AnchorColor.surfaceMuted
        case 1: return AnchorColor.brand.opacity(0.28)
        case 2, 3: return AnchorColor.brand.opacity(0.55)
        default: return AnchorColor.brand.opacity(0.88)
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
