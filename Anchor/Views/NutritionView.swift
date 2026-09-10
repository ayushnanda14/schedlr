import SwiftUI
import SwiftData
import Charts

struct NutritionView: View {
    @Environment(LocalSwiftDataStore.self) private var store
    @Query(filter: #Predicate<UserProfile> { $0.isDeleted == false }) private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<WeightEntry> { $0.isDeleted == false },
        sort: \WeightEntry.date
    ) private var weightEntries: [WeightEntry]
    @Query(filter: #Predicate<DailyChecklistItem> { $0.isDeleted == false }) private var checklistItems: [DailyChecklistItem]

    @State private var weightInput = ""

    private var profile: UserProfile? { profiles.first }
    private var proteinItem: DailyChecklistItem? {
        checklistItems.first { $0.title == "Hit protein target" }
    }

    private var recentEntries: [WeightEntry] {
        Array(weightEntries.suffix(8))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let profile {
                        targetsCard(profile)
                        proteinToggle
                        weightCard(profile)
                        chartCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AnchorScreenBackground())
            .navigationTitle("Nutrition")
            .anchorTabRoot()
            .onAppear {
                if let profile {
                    weightInput = String(format: "%.1f", profile.weightKg)
                }
            }
        }
    }

    private func targetsCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's targets")
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)

            HStack {
                targetTile(
                    title: "Protein",
                    value: String(format: "%.0f g", NutritionMath.proteinTargetG(weightKg: profile.weightKg))
                )
                targetTile(
                    title: "Calories",
                    value: String(format: "%.0f", NutritionMath.calorieTarget(profile: profile))
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.hero)
    }

    private func targetTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)
            Text(value)
                .font(AnchorFont.heading)
                .foregroundStyle(AnchorColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var proteinToggle: some View {
        if let proteinItem, let profile {
            TaskCard(
                icon: "fork.knife",
                title: "Hit protein target",
                subtitle: String(format: "%.0f g today", NutritionMath.proteinTargetG(weightKg: profile.weightKg)),
                isComplete: proteinItem.isCompletedToday()
            ) {
                store.toggleChecklistItem(itemID: proteinItem.id, mode: profile.currentMode)
            }
        }
    }

    private func weightCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight")
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)
            Text("Log a weekly weigh-in. This also updates your protein and calorie targets.")
                .font(AnchorFont.caption)
                .foregroundStyle(AnchorColor.textSecondary)

            HStack {
                TextField("kg", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .anchorField()
                Text("kg")
                    .foregroundStyle(AnchorColor.textSecondary)
                Button("Save") { saveWeight(profile: profile) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(parsedWeight == nil)
                    .accessibilityIdentifier(AnchorAID.nutritionSave)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(AnchorFont.title)
                .foregroundStyle(AnchorColor.textPrimary)

            if recentEntries.count < 2 {
                Text("Log at least two weigh-ins to see a trend.")
                    .font(AnchorFont.subheadline)
                    .foregroundStyle(AnchorColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                Chart(recentEntries, id: \.persistentModelID) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("kg", entry.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AnchorColor.textPrimary)
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("kg", entry.weightKg)
                    )
                    .foregroundStyle(AnchorColor.brand)
                }
                .chartYAxisLabel("kg")
                .frame(height: 200)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .anchorSurface(.raised)
    }

    private var parsedWeight: Double? {
        let normalized = weightInput.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0, value < 400 else { return nil }
        return value
    }

    private func saveWeight(profile: UserProfile) {
        guard let value = parsedWeight else { return }
        store.saveWeight(kg: value, on: Date(), profile: profile)
    }
}

#Preview {
    NutritionView()
        .anchorPreview()
}
