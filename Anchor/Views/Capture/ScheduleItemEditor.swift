import SwiftUI

struct ScheduleItemEditor: View {
    let store: LocalSwiftDataStore
    let item: TodayTimelineItem
    var onFinished: (CaptureConfirmation) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var day: Date
    @State private var hasStartTime: Bool
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var errorMessage: String?
    @State private var confirmRemove = false
    @FocusState private var titleFocused: Bool

    init(
        store: LocalSwiftDataStore,
        item: TodayTimelineItem,
        onFinished: @escaping (CaptureConfirmation) -> Void
    ) {
        self.store = store
        self.item = item
        self.onFinished = onFinished
        _title = State(initialValue: item.title)
        let calendar = store.clock.calendar
        if let start = item.startAt {
            _day = State(initialValue: calendar.startOfDay(for: start))
            _startTime = State(initialValue: start)
            _hasStartTime = State(initialValue: true)
            if let end = item.endAt {
                _durationMinutes = State(initialValue: max(calendar.dateComponents([.minute], from: start, to: end).minute ?? 30, 5))
            } else {
                _durationMinutes = State(initialValue: 30)
            }
        } else {
            _day = State(initialValue: calendar.startOfDay(for: store.clock.now))
            _startTime = State(initialValue: store.clock.now)
            _hasStartTime = State(initialValue: false)
            _durationMinutes = State(initialValue: 30)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .accessibilityIdentifier("schedule.edit.title")
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                        .onChange(of: day) { _, _ in titleFocused = false }
                    if !isException {
                        Toggle("Has a start time", isOn: $hasStartTime)
                            .onChange(of: hasStartTime) { _, _ in titleFocused = false }
                    }
                    if hasStartTime || isException {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                            .onChange(of: startTime) { _, _ in titleFocused = false }
                    }
                    DurationPicker(minutes: $durationMinutes) {
                        titleFocused = false
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Remove from today", role: .destructive) {
                        titleFocused = false
                        confirmRemove = true
                    }
                    .accessibilityIdentifier("schedule.edit.remove")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("schedule.edit.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { titleFocused = false }
                }
            }
            .confirmationDialog("Remove this from today?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { remove() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This won’t rearrange anything else.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var coordinator: CaptureCoordinator {
        CaptureCoordinator(repository: store, clock: store.clock)
    }

    private var isException: Bool { item.exceptionID != nil }

    private func save() {
        titleFocused = false
        let calendar = store.clock.calendar
        let timed = hasStartTime || isException
        do {
            let confirmation = try coordinator.update(
                item: item,
                title: title,
                day: day,
                startHour: timed ? calendar.component(.hour, from: startTime) : nil,
                startMinute: timed ? calendar.component(.minute, from: startTime) : nil,
                durationMinutes: durationMinutes
            )
            Haptics.light()
            onFinished(confirmation)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() {
        let confirmation = coordinator.remove(item)
        Haptics.light()
        onFinished(confirmation)
        dismiss()
    }
}
