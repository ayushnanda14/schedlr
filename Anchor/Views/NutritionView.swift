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
                VStack(alignment: .leading, spacing: 20) {
                    if let profile {
                        targetsCard(profile)
                        proteinToggle
                        weightCard(profile)
                        chartCard
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Nutrition")
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
                .font(.headline)

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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func targetTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
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
                .font(.headline)
            Text("Log a weekly weigh-in. This also updates your protein and calorie targets.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("kg", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("kg")
                    .foregroundStyle(.secondary)
                Button("Save") { saveWeight(profile: profile) }
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedWeight == nil)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.headline)

            if recentEntries.count < 2 {
                Text("Log at least two weigh-ins to see a trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                Chart(recentEntries, id: \.persistentModelID) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("kg", entry.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("kg", entry.weightKg)
                    )
                }
                .chartYAxisLabel("kg")
                .frame(height: 200)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
