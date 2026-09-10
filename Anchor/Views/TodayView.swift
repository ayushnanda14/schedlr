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
    @State private var evidenceSuggestion: RoutineSuggestion?
    @State private var editingSuggestion: RoutineSuggestion?
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
                    VStack(alignment: .leading, spacing: 14) {
                        if let profile {
                            todayHero(profile: profile)

                            if let token = undoCoordinator.token {
                                UndoBanner(message: token.message) {
                                    undoCoordinator.undo(using: store)
                                    refreshProposal()
                                    refreshSuggestion()
                                }
                            } else if let captureNotice {
                                UndoBanner(message: captureNotice)
                            }

                            if profile.currentMode != .away, let summary = pressureSummary(at: timeline.date) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(summary)
                                        .font(AnchorFont.subheadline)
                                        .foregroundStyle(AnchorColor.textPrimary)
                                    Button("Replan") {
                                        refreshProposal()
                                        if let activeProposal {
                                            previewProposal = activeProposal
                                        } else {
                                            captureNotice = "Nothing needs to move."
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .frame(minHeight: 44)
                                    .accessibilityIdentifier("pressure.replan")
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .anchorSurface(.raised)
                                .accessibilityIdentifier("pressure.summary")
                            }
                            if profile.currentMode != .away, let activeProposal {
                                SmartSuggestionCard(
                                    proposal: activeProposal,
                                    onReview: { previewProposal = activeProposal },
                                    onDismiss: { self.activeProposal = nil }
                                )
                            } else if profile.currentMode != .away, let evidenceSuggestion {
                                EvidenceSuggestionCard(
                                    suggestion: evidenceSuggestion,
                                    onTry: { acceptSuggestion(evidenceSuggestion) },
                                    onEdit: { editingSuggestion = evidenceSuggestion },
                                    onDismiss: { dismissSuggestion(evidenceSuggestion) }
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
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .anchorHardScrollEdge(.bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AnchorScreenBackground())
            .navigationTitle("Today")
            .anchorTabRoot()
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
            .sheet(item: $editingSuggestion) { suggestion in
                let coordinator = SuggestionCoordinator(store: store)
                let prefs = coordinator.notificationPreferences()
                SuggestionEditSheet(
                    suggestion: suggestion,
                    initialGymHour: prefs.gymHour,
                    initialSnoozeMinutes: prefs.snoozeMinutes,
                    onSave: { gymHour, snoozeMinutes in
                        acceptSuggestion(
                            suggestion,
                            editedGymHour: gymHour,
                            editedSnoozeMinutes: snoozeMinutes
                        )
                        editingSuggestion = nil
                    },
                    onCancel: { editingSuggestion = nil }
                )
            }
            .onAppear {
                resetLateNightIfNeeded()
                refreshNotifications()
                refreshProposal()
                refreshSuggestion()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    resetLateNightIfNeeded()
                    refreshNotifications()
                    refreshSuggestion()
                }
            }
        }
    }

    @ViewBuilder
    private func todayHero(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formattedDayName())
                    .font(AnchorFont.captionEmphasized)
                    .foregroundStyle(AnchorColor.textSecondary)
                Text(profile.currentMode == .away
                     ? "Away"
                     : (todaySplit == .rest ? "Rest day" : todaySplit.displayName))
                    .font(AnchorFont.display)
                    .foregroundStyle(AnchorColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            modeSwitcher(profile: profile)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
        .accessibilityElement(children: .contain)
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
        .labelsHidden()
        .accessibilityLabel("Mode")
    }

    private var gymShortcut: some View {
        DisclosureGroup("Log today's lifts", isExpanded: $gymExpanded) {
            CompactGymLogger(
                split: todaySplit,
                exercises: exercises,
                sessions: sessions,
                showsChrome: false,
                onEnsureSession: {
                    store.ensureWorkoutSession(splitDay: todaySplit, notes: nil)
                }
            )
            .padding(.top, 8)
        }
        .font(AnchorFont.subheadlineEmphasized)
        .foregroundStyle(AnchorColor.textPrimary)
        .padding(12)
        .anchorSurface(.raised)
    }

    @ViewBuilder
    private func scheduleSection(snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AnchorSectionLabel(title: "Now / Next / Later")

            if let current = snapshot.current {
                timelineBlock(current, stateLabel: "Now", prominence: .now)
                currentActivityActions(current)
            } else if let next = snapshot.next {
                timelineBlock(next, stateLabel: "Next", prominence: .next)
            } else if !snapshot.hasAnyPlannedItems {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No plans yet")
                        .font(AnchorFont.title)
                        .foregroundStyle(AnchorColor.textPrimary)
                    Text("Add a commitment or task to shape your day.")
                        .font(AnchorFont.subheadline)
                        .foregroundStyle(AnchorColor.textSecondary)
                    Button("Add to today") {
                        showCapture = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("today.emptyCapture")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .anchorSurface(.raised)
            }

            if let next = snapshot.next, snapshot.current != nil {
                timelineBlock(next, stateLabel: "Next", prominence: .next)
            }

            if !snapshot.later.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    AnchorSectionLabel(title: "Later")
                        .padding(.bottom, 6)
                    ForEach(Array(snapshot.later.enumerated()), id: \.element.id) { index, item in
                        timelineBlock(item, stateLabel: nil, prominence: .later)
                        if index < snapshot.later.count - 1 {
                            AnchorHairline()
                                .padding(.leading, 34)
                        }
                    }
                }
                .padding(12)
                .anchorSurface(.raised)
            }
        }
    }

    private func timelineBlock(
        _ item: TodayTimelineItem,
        stateLabel: String?,
        prominence: TimelineProminence
    ) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(railColor(for: item.kind, prominence: prominence))
                    .frame(width: 4, height: prominence == .now ? 48 : 32)
                    .padding(.top, 4)
                    .accessibilityHidden(true)

                Image(systemName: icon(for: item.kind))
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.brand)
                    .frame(width: 22, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let stateLabel {
                            StatusPill(text: stateLabel, tone: prominence == .now ? .brand : .neutral)
                        }
                        Text(item.title)
                            .font(prominence == .now ? AnchorFont.heading : AnchorFont.bodyEmphasized)
                            .foregroundStyle(AnchorColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    Text(item.detail)
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.textSecondary)
                    if prominence == .now, let remaining = remainingCopy(for: item) {
                        Text(remaining)
                            .font(AnchorFont.captionEmphasized)
                            .foregroundStyle(AnchorColor.brandDeep)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(prominence == .later ? 6 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .anchorSurface(prominence == .now ? .hero : (prominence == .later ? .flush : .raised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue([stateLabel, item.detail, remainingCopy(for: item)].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Opens edit and remove")
        .contextMenu {
            Button("Edit") { editingItem = item }
            if item.timeBlockID != nil, item.kind != .buffer {
                Button("Mark done") { completeTimelineItem(item) }
            }
            Button("Snooze 30 min") { shift(item, .snooze) }
            Button("Move to tonight") { shift(item, .tonight) }
            Button("Move to tomorrow") { shift(item, .tomorrow) }
            Button("Remove", role: .destructive) {
                let confirmation = CaptureCoordinator(repository: store, clock: store.clock).remove(item)
                handleScheduleMutation(confirmation)
            }
        }
    }

    private func remainingCopy(for item: TodayTimelineItem) -> String? {
        guard let end = item.endAt else { return nil }
        let now = store.clock.now
        guard end > now else { return nil }
        let minutes = max(store.clock.calendar.dateComponents([.minute], from: now, to: end).minute ?? 1, 1)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 {
                return hours == 1 ? "1 h left" : "\(hours) h left"
            }
            return "\(hours) h \(remainder) min left"
        }
        return "\(minutes) min left"
    }

    private func railColor(for kind: TodayTimelineItem.Kind, prominence: TimelineProminence) -> Color {
        if prominence == .now { return AnchorColor.brand }
        switch kind {
        case .fixedCommitment: return AnchorColor.brand
        case .taskBlock: return AnchorColor.accentInfo
        case .buffer: return AnchorColor.border
        case .dayException: return AnchorColor.accentAttention
        }
    }

    @ViewBuilder
    private func currentActivityActions(_ item: TodayTimelineItem) -> some View {
        if item.kind != .buffer {
            HStack(spacing: 12) {
                Menu {
                    Button("I'm not doing \(item.plannedTitle ?? item.title)") {
                        correctCurrent(item, .notThis)
                    }
                    Button("I'm cleaning") { correctCurrent(item, .cleaning) }
                    Button("I'm outside") { correctCurrent(item, .outside) }
                    Button("I'm doing something else") { correctCurrent(item, .other) }
                } label: {
                    Text("Not this")
                        .font(AnchorFont.subheadlineEmphasized)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("today.correctCurrent")

                if item.timeBlockID != nil {
                    Button("Done") { completeTimelineItem(item) }
                        .font(AnchorFont.subheadlineEmphasized)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("today.completeCurrent")
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private enum TimelineProminence {
        case now
        case next
        case later
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
            exceptions: exceptions,
            completedTimeBlockIDs: store.completedTimeBlockIDs(on: now),
            currentOverride: store.currentActivityOverride(for: nil)
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
                    .foregroundStyle(AnchorColor.onBrand)
                    .frame(width: 52, height: 52)
                    .background(AnchorColor.brand)
                    .clipShape(Circle())
                    .shadow(color: AnchorColor.brand.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .accessibilityLabel("Add to today")
            .accessibilityIdentifier("today.add")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            AnchorColor.surface
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: -4)
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) { AnchorHairline() }
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
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.textPrimary)
                if profile.lateNightModeActiveToday {
                    Text("Evening list is abbreviated.")
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.textSecondary)
                }
            }
        }
        .tint(AnchorColor.brand)
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

    private func completeTimelineItem(_ item: TodayTimelineItem) {
        let result = store.logActivityCompletion(item: item)
        captureNotice = nil
        if result == .completed, let event = store.latestActivityEvent(kind: .completed, matching: item) {
            undoCoordinator.register(UndoToken(message: "Marked complete", kind: .activityEvent(event.id)))
        }
    }

    private func correctCurrent(_ item: TodayTimelineItem, _ actual: CurrentActivityKind) {
        let result = store.logActivityCorrection(item: item, actual: actual)
        captureNotice = nil
        if result == .completed, let event = store.latestActivityEvent(kind: .corrected, matching: item) {
            undoCoordinator.register(UndoToken(
                message: "Now: \(actual.displayName)",
                kind: .activityEvent(event.id)
            ))
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

    private func refreshSuggestion() {
        guard let profile, profile.currentMode != .away else {
            evidenceSuggestion = nil
            return
        }
        evidenceSuggestion = SuggestionCoordinator(store: store).evaluate()
    }

    private func acceptSuggestion(
        _ suggestion: RoutineSuggestion,
        editedGymHour: Int? = nil,
        editedSnoozeMinutes: Int? = nil
    ) {
        let token = SuggestionCoordinator(store: store).accept(
            suggestion,
            editedGymHour: editedGymHour,
            editedSnoozeMinutes: editedSnoozeMinutes
        )
        undoCoordinator.register(token)
        captureNotice = nil
        evidenceSuggestion = nil
        Haptics.light()
    }

    private func dismissSuggestion(_ suggestion: RoutineSuggestion) {
        SuggestionCoordinator(store: store).dismiss(suggestion)
        evidenceSuggestion = nil
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
