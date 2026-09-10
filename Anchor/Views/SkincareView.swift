import SwiftUI
import SwiftData

struct SkincareView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @Query(
        filter: #Predicate<SkincareNightLog> { $0.isDeleted == false },
        sort: \SkincareNightLog.date,
        order: .reverse
    ) private var nightLogs: [SkincareNightLog]
    @Query(filter: #Predicate<DailyChecklistItem> { $0.isDeleted == false }) private var checklistItems: [DailyChecklistItem]
    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<RoutineStep> { $0.isDeleted == false },
        sort: \RoutineStep.sortIndex
    ) private var routineSteps: [RoutineStep]

    private var tonightLog: SkincareNightLog? {
        nightLogs.first { Calendar.current.isDateInToday($0.date) }
    }

    private var lastNightLog: SkincareNightLog? {
        nightLogs.first { !Calendar.current.isDateInToday($0.date) }
    }

    private var selectedActive: SkincareActive {
        if tonightLog != nil {
            return SkincareActive.fromStored(tonightLog?.activeUsed)
        }
        return SkincareRotation.recommended(after: SkincareActive.fromStored(lastNightLog?.activeUsed))
    }

    private var recommendedActive: SkincareActive {
        SkincareRotation.recommended(after: SkincareActive.fromStored(lastNightLog?.activeUsed))
    }

    private var shouldWarnSpacing: Bool {
        let last = SkincareActive.fromStored(lastNightLog?.activeUsed)
        return last.needsSpacing && last == selectedActive
    }

    private var morningSteps: [RoutineStep] {
        routineSteps.filter { $0.category == .skincareAM }
    }

    private var eveningSteps: [RoutineStep] {
        routineSteps.filter { $0.category == .skincarePM }
    }

    private var highlightedMorningStepID: UUID? {
        morningSteps.first { !store.isRoutineStepCompleteToday(stepID: $0.id) }?.id
    }

    private var highlightedEveningStepID: UUID? {
        eveningSteps.first { !store.isRoutineStepCompleteToday(stepID: $0.id) }?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    amSection
                    pmSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(AnchorScreenBackground())
            .navigationTitle("Skincare")
            .anchorTabRoot()
            .anchorHardScrollEdge([.bottom])
            .onAppear {
                store.ensureRoutineCatalog()
                store.backfillRoutineCompletions()
                syncTodayChecklist()
            }
        }
    }

    private var amSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Morning")
                .font(AnchorFont.section)
                .foregroundStyle(AnchorColor.textSecondary)
            ForEach(morningSteps, id: \.persistentModelID) { step in
                stepToggle(step, highlighted: step.id == highlightedMorningStepID)
            }
        }
    }

    private var pmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evening")
                .font(AnchorFont.section)
                .foregroundStyle(AnchorColor.textSecondary)

            ForEach(eveningSteps.filter { $0.key == "skincare.pm.cleanser" }, id: \.persistentModelID) { step in
                stepToggle(step, highlighted: step.id == highlightedEveningStepID)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Active")
                    .font(AnchorFont.subheadlineEmphasized)
                    .foregroundStyle(AnchorColor.textPrimary)
                Picker("Active", selection: activeBinding) {
                    ForEach(SkincareActive.allCases) { active in
                        Text(active.displayName).tag(active)
                    }
                }
                .pickerStyle(.menu)

                Text("Suggested tonight: \(recommendedActive.displayName)")
                    .font(AnchorFont.caption)
                    .foregroundStyle(AnchorColor.textSecondary)

                if shouldWarnSpacing {
                    Text("Same strong active two nights in a row. Adapalene and benzoyl peroxide usually need spacing while you ramp up.")
                        .font(AnchorFont.caption)
                        .foregroundStyle(AnchorColor.accentAttention)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnchorColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                    .strokeBorder(AnchorColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous))

            ForEach(eveningSteps.filter { $0.key != "skincare.pm.cleanser" }, id: \.persistentModelID) { step in
                stepToggle(step, highlighted: false)
            }

            Toggle(
                "Irritation today",
                isOn: Binding(
                    get: { tonightLog?.irritationFlag ?? false },
                    set: { newValue in
                        store.upsertSkincareNightLog { log in
                            log.irritationFlag = newValue
                        }
                    }
                )
            )
            .tint(AnchorColor.brand)
            .padding(12)
            .background(AnchorColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                    .strokeBorder(AnchorColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous))
        }
    }

    private func stepToggle(_ step: RoutineStep, highlighted: Bool) -> some View {
        let complete = store.isRoutineStepCompleteToday(stepID: step.id)
        return Button {
            store.toggleRoutineStep(stepID: step.id)
            if !complete, step.category == .skincarePM, tonightLog == nil {
                store.upsertSkincareNightLog { log in
                    if log.activeUsed == nil {
                        log.activeUsed = recommendedActive.storedValue
                    }
                }
            }
            syncTodayChecklist()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: skincareIcon(for: step.title))
                    .font(AnchorFont.body)
                    .foregroundStyle((highlighted && !complete) ? AnchorColor.brand : AnchorColor.textSecondary)
                    .frame(width: 28, height: 28)

                Text(step.title)
                    .font(AnchorFont.bodyEmphasized)
                    .foregroundStyle(AnchorColor.textPrimary)
                    .strikethrough(complete)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(complete ? AnchorColor.brand : AnchorColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .background(AnchorColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                    .strokeBorder(
                        (highlighted && !complete) ? AnchorColor.brand : AnchorColor.border,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(step.title)
        .accessibilityValue(complete ? "Complete" : "Not complete")
        .accessibilityHint(complete ? "Marks as not done" : "Marks as done")
    }

    private func skincareIcon(for title: String) -> String {
        if title.localizedCaseInsensitiveContains("vitamin") { return "sparkle" }
        if title.localizedCaseInsensitiveContains("sunscreen") { return "sun.max" }
        return "drop"
    }

    private var activeBinding: Binding<SkincareActive> {
        Binding(
            get: { selectedActive },
            set: { newValue in
                store.upsertSkincareNightLog { log in
                    log.activeUsed = newValue.storedValue
                }
                syncTodayChecklist()
            }
        )
    }

    private func syncTodayChecklist() {
        let amDone = morningSteps.filter { !$0.isOptional }.allSatisfy {
            store.isRoutineStepCompleteToday(stepID: $0.id)
        }
        setChecklist("AM skincare", completed: amDone)

        let pmDone = eveningSteps.filter { !$0.isOptional }.allSatisfy {
            store.isRoutineStepCompleteToday(stepID: $0.id)
        }
        setChecklist("PM skincare", completed: pmDone)
    }

    private func setChecklist(_ title: String, completed: Bool) {
        guard let item = checklistItems.first(where: { $0.title == title }) else { return }
        guard item.isCompletedToday() != completed else { return }
        let mode = profiles.first?.currentMode ?? .normal
        store.toggleChecklistItem(itemID: item.id, mode: mode)
    }
}

#Preview {
    SkincareView()
        .anchorPreview()
}
