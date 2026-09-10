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

    @State private var amCleanser = false
    @State private var amVitaminC = false
    @State private var amMoisturizer = false
    @State private var amSunscreen = false
    @State private var pmCleanser = false
    @State private var pmMoisturizer = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    amSection
                    pmSection
                }
                .padding()
            }
            .navigationTitle("Skincare")
            .onAppear { loadDayFlags() }
        }
    }

    private var amSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Morning")
                .font(.headline)

            stepToggle("Cleanser", isOn: $amCleanser, key: "skincare.am.cleanser")
            stepToggle("Vitamin C (optional)", isOn: $amVitaminC, key: "skincare.am.vitaminc")
            stepToggle("Moisturizer", isOn: $amMoisturizer, key: "skincare.am.moisturizer")
            stepToggle("Sunscreen", isOn: $amSunscreen, key: "skincare.am.sunscreen")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evening")
                .font(.headline)

            stepToggle("Cleanser", isOn: $pmCleanser, key: "skincare.pm.cleanser")

            VStack(alignment: .leading, spacing: 8) {
                Text("Active")
                    .font(.subheadline)
                Picker("Active", selection: activeBinding) {
                    ForEach(SkincareActive.allCases) { active in
                        Text(active.displayName).tag(active)
                    }
                }
                .pickerStyle(.menu)

                Text("Suggested tonight: \(recommendedActive.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if shouldWarnSpacing {
                    Text("Same strong active two nights in a row. Adapalene and benzoyl peroxide usually need spacing while you ramp up.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            stepToggle("Moisturizer", isOn: $pmMoisturizer, key: "skincare.pm.moisturizer")

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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stepToggle(_ title: String, isOn: Binding<Bool>, key: String) -> some View {
        TaskCard(
            icon: skincareIcon(for: title),
            title: title,
            isComplete: isOn.wrappedValue,
            prominence: .standard
        ) {
            let newValue = !isOn.wrappedValue
            isOn.wrappedValue = newValue
            DayScopedFlag.set(key, newValue)
            if newValue, key.hasPrefix("skincare.pm"), tonightLog == nil {
                store.upsertSkincareNightLog { log in
                    if log.activeUsed == nil {
                        log.activeUsed = recommendedActive.storedValue
                    }
                }
            }
            syncTodayChecklist()
        }
    }

    private func skincareIcon(for title: String) -> String {
        if title.localizedCaseInsensitiveContains("vitamin") { return "sparkle" }
        if title.localizedCaseInsensitiveContains("sunscreen") { return "sun.max" }
        if title.localizedCaseInsensitiveContains("moisturizer") { return "drop.fill" }
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

    private func loadDayFlags() {
        amCleanser = DayScopedFlag.isOn("skincare.am.cleanser")
        amVitaminC = DayScopedFlag.isOn("skincare.am.vitaminc")
        amMoisturizer = DayScopedFlag.isOn("skincare.am.moisturizer")
        amSunscreen = DayScopedFlag.isOn("skincare.am.sunscreen")
        pmCleanser = DayScopedFlag.isOn("skincare.pm.cleanser")
        pmMoisturizer = DayScopedFlag.isOn("skincare.pm.moisturizer")
    }

    private func syncTodayChecklist() {
        let amDone = amCleanser && amMoisturizer && amSunscreen
        setChecklist("AM skincare", completed: amDone)

        let pmDone = pmCleanser && pmMoisturizer
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
