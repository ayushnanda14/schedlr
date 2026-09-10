import SwiftUI
import SwiftData

struct TodayView: View {
    @Binding var showSettings: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(LocalSwiftDataStore.self) private var store
    @Environment(UndoCoordinator.self) private var undoCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<DailyChecklistItem> { $0.isDeleted == false },
        sort: \DailyChecklistItem.title
    ) private var checklistItems: [DailyChecklistItem]
    @Query(
        filter: #Predicate<PeriodicTask> { $0.isDeleted == false },
        sort: \PeriodicTask.title
    ) private var periodicTasks: [PeriodicTask]
    @Query(filter: #Predicate<GymScheduleDay> { $0.isDeleted == false }) private var gymSchedule: [GymScheduleDay]
    @Query(
        filter: #Predicate<Exercise> { $0.isDeleted == false },
        sort: \Exercise.orderIndex
    ) private var exercises: [Exercise]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isDeleted == false },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var gymExpanded = false
    @State private var showCapture = false
    @State private var captureNotice: String?
    @State private var editingItem: TodayTimelineItem?
    @State private var activeProposal: PlanProposal?
    @State private var previewProposal: PlanProposal?
    private let todayComposer = TodayComposer()

    private var profile: UserProfile? { profiles.first }
    private var todaySplit: SplitDay { GymDay.split(schedule: gymSchedule) }

    private var dueTasks: [PeriodicTask] {
        guard let profile, profile.currentMode == .livingAlone else { return [] }
        return periodicTasks.filter {
            $0.activeInModes.contains(profile.currentMode) && $0.isDueTodayOrOverdue()
        }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let profile {
                            modeSwitcher(profile: profile)
                            if profile.currentMode != .away {
                                gymHeader
                            }

                            if let token = undoCoordinator.token {
                                UndoBanner(message: token.message) {
                                    undoCoordinator.undo(using: store)
                                    refreshProposal()
                                }
                            } else if let captureNotice {
                                UndoBanner(message: captureNotice)
                            }

                            if profile.currentMode != .away, let summary = pressureSummary(at: timeline.date) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(summary)
                                        .font(.subheadline)
                                    Button("Replan") {
                                        refreshProposal()
                                        if let activeProposal {
                                            previewProposal = activeProposal
                                        } else {
                                            captureNotice = "Nothing needs to move."
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityIdentifier("pressure.replan")
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("pressure.summary")
                            }
                            if profile.currentMode != .away, let activeProposal {
                                SmartSuggestionCard(
                                    proposal: activeProposal,
                                    onReview: { previewProposal = activeProposal },
                                    onDismiss: { self.activeProposal = nil }
                                )
                            }

                            if profile.currentMode != .away {
                                scheduleSection(snapshot: todaySnapshot(at: timeline.date, profile: profile))
                            }

                            SmartTodayList(
                                profile: profile,
                                items: checklistItems.filter { $0.applicableModes.contains(profile.currentMode) },
                                dueTasks: dueTasks,
                                now: timeline.date,
                                onToggleItem: { item in
                                    completeChecklist(item, mode: profile.currentMode)
                                },
                                onMarkTask: { task in
                                    completePeriodicTask(task)
                                }
                            )

                            if profile.currentMode != .away, todaySplit != .rest {
                                gymShortcut
                            }
                        } else {
                            ContentUnavailableView(
                                "No profile",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text("Complete onboarding to get started.")
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock")
                    }
                    .accessibilityLabel("History")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if profile != nil {
                    bottomBar
                }
            }
            .sheet(isPresented: $showCapture) {
                QuickCaptureSheet(store: store) { confirmation in
                    handleScheduleMutation(confirmation)
                }
            }
            .sheet(item: $editingItem) { item in
                ScheduleItemEditor(store: store, item: item) { confirmation in
                    handleScheduleMutation(confirmation)
                }
            }
            .sheet(item: $previewProposal) { proposal in
                ScheduleChangePreview(
                    proposal: proposal,
                    onApply: { applyProposal(proposal) },
                    onDismiss: { activeProposal = nil }
                )
            }
            .onAppear {
                resetLateNightIfNeeded()
                refreshNotifications()
                refreshProposal()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    resetLateNightIfNeeded()
                    refreshNotifications()
                }
            }
        }
    }

    @ViewBuilder
    private func modeSwitcher(profile: UserProfile) -> some View {
        Picker("Mode", selection: Binding(
            get: { profile.currentMode },
            set: { newMode in
                profile.currentMode = newMode
                store.persist(profile)
                refreshNotifications()
            }
        )) {
            ForEach(AppMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var gymHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formattedDayName())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(todaySplit == .rest ? "Rest day" : todaySplit.displayName)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var gymShortcut: some View {
        DisclosureGroup("Log today's lifts", isExpanded: $gymExpanded) {
            CompactGymLogger(
                split: todaySplit,
                exercises: exercises,
                sessions: sessions,
                onEnsureSession: {
                    store.ensureWorkoutSession(splitDay: todaySplit, notes: nil)
                }
            )
            .padding(.top, 8)
        }
        .font(.subheadline)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func scheduleSection(snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Now / Next / Later")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let current = snapshot.current {
                timelineBlock(current, stateLabel: "Now")
            } else if let next = snapshot.next {
                timelineBlock(next, stateLabel: "Next")
            } else if !snapshot.hasAnyPlannedItems {
                ContentUnavailableView {
                    Label("No plans yet", systemImage: "calendar.badge.plus")
                } description: {
                    Text("Add a commitment or task to shape your day.")
                } actions: {
                    Button("Add to today") {
                        showCapture = true
                    }
                    .accessibilityIdentifier("today.emptyCapture")
                }
            }

            if let next = snapshot.next, snapshot.current != nil {
                timelineBlock(next, stateLabel: "Next")
            }

            if !snapshot.later.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Later")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(snapshot.later) { item in
                        timelineBlock(item, stateLabel: nil)
                    }
                }
            }
        }
    }

    private func timelineBlock(_ item: TodayTimelineItem, stateLabel: String?) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon(for: item.kind))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let stateLabel {
                            Text(stateLabel.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens edit and remove")
        .contextMenu {
            Button("Edit") { editingItem = item }
            Button("Snooze 30 min") { shift(item, .snooze) }
            Button("Move to tonight") { shift(item, .tonight) }
            Button("Move to tomorrow") { shift(item, .tomorrow) }
            Button("Remove", role: .destructive) {
                let confirmation = CaptureCoordinator(repository: store, clock: store.clock).remove(item)
                handleScheduleMutation(confirmation)
            }
        }
    }

    private func icon(for kind: TodayTimelineItem.Kind) -> String {
        switch kind {
        case .fixedCommitment: return "calendar"
        case .taskBlock: return "checklist"
        case .buffer: return "clock"
        case .dayException: return "calendar.badge.exclamationmark"
        }
    }

    private func todaySnapshot(at now: Date, profile: UserProfile) -> TodaySnapshot {
        let calendar = store.clock.calendar
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let dayInterval = DateInterval(start: start, end: end)

        // Away mode intentionally suppresses timeline interpretation.
        if profile.currentMode == .away {
            return TodaySnapshot(now: now, current: nil, next: nil, later: [])
        }

        let activities = store.fetchActivities()
        let planTasks = store.fetchPlanTasks(includeClosed: false)
        let blocks = store.fetchTimeBlocks(overlapping: dayInterval)
        let exceptions = store.fetchExceptions(overlapping: dayInterval)

        return todayComposer.compose(
            now: now,
            activities: activities,
            planTasks: planTasks,
            timeBlocks: blocks,
            exceptions: exceptions
        )
    }

    private func pressureSummary(at now: Date) -> String? {
        ProposalCoordinator(repository: store, clock: store.clock)
            .currentPressure(now: now)
            .summary
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            if let profile, profile.currentMode != .away {
                lateNightBar(profile: profile)
            } else {
                Spacer(minLength: 0)
            }
            Button {
                showCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add to today")
            .accessibilityIdentifier("today.add")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func lateNightBar(profile: UserProfile) -> some View {
        Toggle(isOn: Binding(
            get: { profile.lateNightModeActiveToday },
            set: { isOn in
                if isOn {
                    profile.activateLateNightMode()
                } else {
                    profile.lateNightModeActiveToday = false
                    profile.lateNightActivatedOn = nil
                    profile.markDirty()
                }
                try? modelContext.save()
                refreshNotifications()
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Running late tonight")
                    .font(.subheadline.weight(.medium))
                if profile.lateNightModeActiveToday {
                    Text("Evening list is abbreviated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func handleScheduleMutation(_ confirmation: CaptureConfirmation) {
        captureNotice = confirmation.conflictWarning ?? confirmation.summary
        undoCoordinator.clear()
        refreshProposal()
    }

    private func completeChecklist(_ item: DailyChecklistItem, mode: AppMode) {
        let completing = !item.isCompletedToday()
        store.toggleChecklistItem(itemID: item.id, mode: mode)
        captureNotice = nil
        if completing {
            undoCoordinator.register(UndoToken(message: "Marked complete", kind: .checklist(item.id)))
        } else {
            undoCoordinator.clear()
            captureNotice = "Undone"
        }
    }

    private func completePeriodicTask(_ task: PeriodicTask) {
        let result = store.logPeriodicTaskCompletion(taskID: task.id)
        captureNotice = nil
        if result == .completed {
            undoCoordinator.register(UndoToken(message: "Marked complete", kind: .periodicTask(task.id)))
        }
    }

    private func shift(_ item: TodayTimelineItem, _ kind: ScheduleShift) {
        let beforeStart = item.startAt
        let beforeEnd = item.endAt
        do {
            _ = try CaptureCoordinator(repository: store, clock: store.clock).shift(item, kind)
            let message: String
            switch kind {
            case .snooze: message = "Moved 30 minutes later."
            case .tonight: message = "Moved to tonight."
            case .tomorrow: message = "Moved to tomorrow."
            }
            undoCoordinator.register(UndoToken(
                message: message,
                kind: .scheduleShift(item: item, beforeStart: beforeStart, beforeEnd: beforeEnd)
            ))
            captureNotice = nil
            refreshProposal()
            Haptics.light()
        } catch {
            captureNotice = error.localizedDescription
        }
    }

    private func refreshProposal() {
        guard let profile, profile.currentMode != .away else {
            activeProposal = nil
            return
        }
        activeProposal = ProposalCoordinator(repository: store, clock: store.clock)
            .makeProposal(now: store.clock.now)
    }

    private func applyProposal(_ proposal: PlanProposal) {
        do {
            let applied = try ProposalCoordinator(repository: store, clock: store.clock).apply(proposal)
            undoCoordinator.register(UndoToken(message: applied.reason, kind: .proposal(applied)))
            activeProposal = nil
            captureNotice = nil
            Haptics.light()
        } catch {
            captureNotice = error.localizedDescription
        }
    }

    private func resetLateNightIfNeeded() {
        guard let profile else { return }
        profile.resetLateNightIfNeeded()
        try? modelContext.save()
    }

    private func refreshNotifications() {
        NotificationScheduler.refreshSoon(context: modelContext)
    }
}

#Preview {
    TodayView(showSettings: .constant(false))
        .anchorPreview()
}
