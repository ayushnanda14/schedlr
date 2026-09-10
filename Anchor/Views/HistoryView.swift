import SwiftUI

struct HistoryView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @State private var range: HistoryRange = .fourWeeks
    @State private var filter: HistoryFilter = .all

    var body: some View {
        let snapshot = store.historySnapshot(range: range, filter: filter)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker
                heatmap
                if !snapshot.categorySummaries.isEmpty {
                    summaries(snapshot)
                }
                if !snapshot.cadence.isEmpty {
                    cadenceSection(snapshot)
                }
                if !snapshot.workoutProgression.isEmpty {
                    workoutSection(snapshot)
                }
                if let schedule = snapshot.schedule {
                    scheduleSection(schedule)
                }
                if !snapshot.reflections.isEmpty {
                    reflectionsSection(snapshot)
                }
                filterChips
                eventList(snapshot)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(AnchorScreenBackground())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AnchorColor.background, for: .navigationBar)
        .accessibilityIdentifier(AnchorAID.historyRoot)
    }

    private var rangePicker: some View {
        Picker("History range", selection: $range) {
            ForEach(HistoryRange.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("History range")
        .accessibilityValue(range.displayName)
        .accessibilityIdentifier(AnchorAID.historyRange)
    }

    private var heatmap: some View {
        let counts = store.heatmapCounts(weeks: 12)
        let activeDays = counts.values.filter { $0 > 0 }.count
        return VStack(alignment: .leading, spacing: 8) {
            AnchorSectionLabel(title: "Last 12 weeks")
            ConsistencyHeatmap(counts: counts)
            Text(activeDays == 1 ? "1 day with logged activity" : "\(activeDays) days with logged activity")
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity in the last 12 weeks")
        .accessibilityValue(activeDays == 1 ? "1 day with logged activity" : "\(activeDays) days with logged activity")
        .accessibilityIdentifier(AnchorAID.historyHeatmap)
    }

    private func summaries(_ snapshot: HistoryInsightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AnchorSectionLabel(title: "In this window")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                ForEach(snapshot.categorySummaries) { summary in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(summary.count)")
                            .font(AnchorFont.heading)
                            .foregroundStyle(AnchorColor.textPrimary)
                        Text(summary.filter.displayName)
                            .font(AnchorFont.caption)
                            .foregroundStyle(AnchorColor.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(summary.caption)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityIdentifier(AnchorAID.historySummaries)
    }

    private func cadenceSection(_ snapshot: HistoryInsightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AnchorSectionLabel(title: "House cadence")
            ForEach(snapshot.cadence) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AnchorFont.bodyEmphasized)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text(item.detail)
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityIdentifier(AnchorAID.historyCadence)
    }

    private func workoutSection(_ snapshot: HistoryInsightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AnchorSectionLabel(title: "Workout progression")
            ForEach(snapshot.workoutProgression) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AnchorFont.bodyEmphasized)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text(item.detail)
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityIdentifier(AnchorAID.historyWorkout)
    }

    private func scheduleSection(_ schedule: HistoryScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AnchorSectionLabel(title: "Schedule changes")
            Text(schedule.caption)
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AnchorAID.historySchedule)
    }

    private func reflectionsSection(_ snapshot: HistoryInsightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AnchorSectionLabel(title: "What stands out")
            ForEach(snapshot.reflections) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AnchorFont.subheadlineEmphasized)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text(item.reason)
                        .font(AnchorFont.subheadline)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text(item.confidenceCopy)
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
        .accessibilityIdentifier(AnchorAID.historyReflections)
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
                            .frame(minHeight: 44)
                            .anchorChoiceChip(selected: filter == chip)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chip.displayName)
                    .accessibilityValue(filter == chip ? "Selected" : "Not selected")
                    .accessibilityAddTraits(filter == chip ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier(AnchorAID.historyFilterPrefix + chip.rawValue)
                }
            }
        }
    }

    @ViewBuilder
    private func eventList(_ snapshot: HistoryInsightSnapshot) -> some View {
        if snapshot.entries.isEmpty {
            Text(snapshot.emptyCopy)
                .font(AnchorFont.subheadline)
                .foregroundStyle(AnchorColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .accessibilityIdentifier(AnchorAID.historyEmpty)
        } else {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.entries) { entry in
                    historyRow(entry)
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
                .frame(width: 28, height: 28)
                .foregroundStyle(AnchorColor.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.textPrimary)
                Text(entry.detail)
                    .font(AnchorFont.caption)
                    .foregroundStyle(AnchorColor.textSecondary)
            }
            Spacer(minLength: 0)
            Text(entry.date.formatted(.relative(presentation: .named)))
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
        .anchorSurface(.raised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.context.displayName)")
        .accessibilityValue("\(entry.detail), \(entry.date.formatted(.relative(presentation: .named)))")
    }
}

struct ConsistencyHeatmap: View {
    let counts: [Date: Int]

    private let weeks = 12
    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let date = dateFor(week: week, weekday: weekday)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(fill(for: date))
                                .frame(width: 11, height: 11)
                                .accessibilityHidden(true)
                        }
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
        case 1: return AnchorColor.border
        case 2, 3: return AnchorColor.textSecondary.opacity(0.45)
        default: return AnchorColor.textPrimary.opacity(0.42)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if sets.isEmpty {
                    Text("No sets logged.")
                        .font(AnchorFont.subheadline)
                        .foregroundStyle(AnchorColor.textSecondary)
                } else {
                    ForEach(sets, id: \.persistentModelID) { set in
                        HStack {
                            Text("\(set.exerciseName)  ·  set \(set.setNumber)")
                                .font(AnchorFont.bodyEmphasized)
                                .foregroundStyle(AnchorColor.textPrimary)
                            Spacer()
                            Text("\(Int(set.weightKg)) kg × \(set.reps)")
                                .font(AnchorFont.subheadline)
                                .foregroundStyle(AnchorColor.textSecondary)
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(16)
        }
        .background(AnchorScreenBackground())
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PeriodicTaskHistoryDetailView: View {
    let title: String
    let dates: [Date]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if dates.isEmpty {
                    Text("No completions logged.")
                        .font(AnchorFont.subheadline)
                        .foregroundStyle(AnchorColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(dates, id: \.self) { date in
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(AnchorFont.body)
                            .foregroundStyle(AnchorColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(16)
        }
        .background(AnchorScreenBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}