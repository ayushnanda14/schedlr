import SwiftUI

struct QuickCaptureSheet: View {
    let store: LocalSwiftDataStore
    var onSaved: (CaptureConfirmation) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var draft: CaptureDraft?
    @State private var showingDetails = false
    @State private var errorMessage: String?
    @FocusState private var focus: CaptureFocus?

    private enum CaptureFocus: Hashable {
        case text
        case title
    }

    private var interpreter: CaptureInterpreter {
        CaptureInterpreter(calendar: store.clock.calendar)
    }

    private var coordinator: CaptureCoordinator {
        CaptureCoordinator(repository: store, clock: store.clock)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Dentist tomorrow 3pm 45 min", text: $text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .textInputAutocapitalization(.sentences)
                            .focused($focus, equals: .text)
                            .id(CaptureFocus.text)
                            .accessibilityLabel("Capture")
                            .accessibilityIdentifier("capture.text")
                            .onChange(of: text) { _, newValue in
                                reinterpret(newValue)
                            }

                        exceptionPresets

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let draft {
                            chipRow(draft)
                            if showingDetails {
                                details(draft)
                                    .id("captureDetails")
                            }
                        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Add a title to save this.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focus) { _, newValue in
                    guard let newValue else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
                .onChange(of: showingDetails) { _, showing in
                    dismissKeyboard()
                    guard showing else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("captureDetails", anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Add to today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("capture.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if draft?.intent != .ambiguous || draft?.exceptionKind != nil {
                        Button("Save") {
                            dismissKeyboard()
                            save()
                        }
                        .disabled(!canSave)
                        .accessibilityIdentifier("capture.save")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let draft, draft.intent == .ambiguous, draft.exceptionKind == nil {
                        HStack(spacing: 8) {
                            Button("Save as commitment") {
                                dismissKeyboard()
                                save(intent: .commitment)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("capture.saveCommitment")
                            Button("Save as task") {
                                dismissKeyboard()
                                save(intent: .flexibleTask)
                            }
                            .buttonStyle(.bordered)
                            .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("capture.saveTask")
                        }
                    }
                    Button(showingDetails ? "Hide details" : "Edit details") {
                        dismissKeyboard()
                        showingDetails.toggle()
                    }
                    .font(.subheadline)
                    .disabled(draft == nil)
                    .accessibilityIdentifier("capture.editDetails")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            reinterpret(text)
            focus = .text
        }
    }

    private var canSave: Bool {
        guard let draft else { return false }
        return !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (draft.exceptionKind != nil ? draft.hasStartTime : draft.intent != .ambiguous)
    }

    @ViewBuilder
    private var exceptionPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add an exception")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DayExceptionPreset.all) { preset in
                        Button(preset.kind.displayName) {
                            applyExceptionPreset(preset)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(draft?.exceptionKind == preset.kind ? Color.primary : Color(.secondarySystemBackground))
                        .foregroundStyle(draft?.exceptionKind == preset.kind ? Color(.systemBackground) : Color.primary)
                        .clipShape(Capsule())
                        .accessibilityIdentifier("capture.exception.\(preset.kind.rawValue)")
                    }
                }
            }
        }
    }

    private func applyExceptionPreset(_ preset: DayExceptionPreset) {
        dismissKeyboard()
        let calendar = store.clock.calendar
        let now = store.clock.now
        var start = now
        if let hour = preset.startHour {
            start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            if start < now {
                start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            }
        }
        let title = preset.kind == .custom && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? text.trimmingCharacters(in: .whitespacesAndNewlines)
            : preset.kind.displayName
        draft = CaptureDraft(
            rawText: title,
            title: title,
            day: calendar.startOfDay(for: start),
            startHour: calendar.component(.hour, from: start),
            startMinute: calendar.component(.minute, from: start),
            durationMinutes: preset.durationMinutes,
            deadline: nil,
            priority: .normal,
            intent: .commitment,
            inferred: [.intent],
            userEdited: [.day, .startTime, .duration, .intent],
            exceptionKind: preset.kind
        )
        text = title
        showingDetails = true
    }

    @ViewBuilder
    private func chipRow(_ draft: CaptureDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anchor understood")
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowChips(items: chips(for: draft)) { chip in
                dismissKeyboard()
                showingDetails = true
                _ = chip
            }
            Text("Inferred details stay visible so you can change them before saving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func details(_ draft: CaptureDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: titleBinding)
                .focused($focus, equals: .title)
                .id(CaptureFocus.title)
            DatePicker("Day", selection: dayBinding, displayedComponents: .date)
            Toggle("Has a start time", isOn: hasTimeBinding)
            if draft.hasStartTime {
                DatePicker("Starts", selection: timeBinding, displayedComponents: .hourAndMinute)
            }
            DurationPicker(minutes: durationBinding, onEdit: dismissKeyboard)
            if draft.exceptionKind == nil {
                Picker("Type", selection: intentBinding) {
                    Text("Commitment").tag(CaptureIntent.commitment)
                    Text("Flexible task").tag(CaptureIntent.flexibleTask)
                }
                .pickerStyle(.segmented)
                Picker("Priority", selection: priorityBinding) {
                    ForEach(PlanTaskPriority.allCases) { priority in
                        Text(priority.rawValue.capitalized).tag(priority)
                    }
                }
            } else {
                Text("This occupies time today. It does not change your routine mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private func chips(for draft: CaptureDraft) -> [CaptureChip] {
        var items: [CaptureChip] = [
            CaptureChip(id: "title", label: draft.title, inferred: draft.inferred.contains(.title)),
            CaptureChip(id: "day", label: dayLabel(draft.day), inferred: draft.inferred.contains(.day))
        ]
        if let hour = draft.startHour {
            items.append(CaptureChip(
                id: "time",
                label: timeLabel(hour: hour, minute: draft.startMinute ?? 0),
                inferred: draft.inferred.contains(.startTime)
            ))
        }
        if let duration = draft.durationMinutes {
            items.append(CaptureChip(
                id: "duration",
                label: DurationFormatting.string(duration),
                inferred: draft.inferred.contains(.duration)
            ))
        }
        items.append(CaptureChip(
            id: "intent",
            label: draft.exceptionKind?.displayName ?? intentLabel(draft.intent),
            inferred: draft.inferred.contains(.intent)
        ))
        if draft.priority != .normal {
            items.append(CaptureChip(
                id: "priority",
                label: draft.priority.rawValue.capitalized,
                inferred: draft.inferred.contains(.priority)
            ))
        }
        if let deadline = draft.deadline {
            items.append(CaptureChip(
                id: "deadline",
                label: "Due \(deadline.formatted(date: .abbreviated, time: .shortened))",
                inferred: draft.inferred.contains(.deadline)
            ))
        }
        return items
    }

    private func reinterpret(_ value: String) {
        errorMessage = nil
        switch interpreter.interpret(value, now: store.clock.now, preserving: draft) {
        case .empty:
            draft = nil
        case .parsed(let next):
            draft = next
        case .invalid(let message):
            draft = nil
            errorMessage = message
        }
    }

    private func save(intent: CaptureIntent? = nil) {
        guard var draft else { return }
        if let intent {
            draft.intent = intent
            draft.apply(.intent)
            self.draft = draft
        }
        do {
            let result = try coordinator.confirm(draft)
            Haptics.light()
            onSaved(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { draft?.title ?? "" },
            set: { value in
                draft?.title = value
                draft?.apply(.title)
            }
        )
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { draft?.day ?? store.clock.now },
            set: { value in
                dismissKeyboard()
                draft?.day = store.clock.calendar.startOfDay(for: value)
                draft?.apply(.day)
            }
        )
    }

    private var hasTimeBinding: Binding<Bool> {
        Binding(
            get: { draft?.hasStartTime ?? false },
            set: { enabled in
                dismissKeyboard()
                if enabled {
                    let now = store.clock.now
                    draft?.startHour = store.clock.calendar.component(.hour, from: now)
                    draft?.startMinute = store.clock.calendar.component(.minute, from: now)
                    if draft?.durationMinutes == nil { draft?.durationMinutes = 30 }
                } else {
                    draft?.startHour = nil
                    draft?.startMinute = nil
                }
                draft?.apply(.startTime)
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                draft?.startAt(calendar: store.clock.calendar) ?? store.clock.now
            },
            set: { value in
                dismissKeyboard()
                draft?.startHour = store.clock.calendar.component(.hour, from: value)
                draft?.startMinute = store.clock.calendar.component(.minute, from: value)
                draft?.apply(.startTime)
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { draft?.durationMinutes ?? 30 },
            set: { value in
                dismissKeyboard()
                draft?.durationMinutes = value
                draft?.apply(.duration)
            }
        )
    }

    private var intentBinding: Binding<CaptureIntent> {
        Binding(
            get: { draft?.intent == .ambiguous ? .flexibleTask : (draft?.intent ?? .flexibleTask) },
            set: { value in
                dismissKeyboard()
                draft?.intent = value
                draft?.apply(.intent)
            }
        )
    }

    private var priorityBinding: Binding<PlanTaskPriority> {
        Binding(
            get: { draft?.priority ?? .normal },
            set: { value in
                dismissKeyboard()
                draft?.priority = value
                draft?.apply(.priority)
            }
        )
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = store.clock.calendar
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func timeLabel(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.calendar = store.clock.calendar
        components.hour = hour
        components.minute = minute
        return (components.date ?? store.clock.now).formatted(date: .omitted, time: .shortened)
    }

    private func intentLabel(_ intent: CaptureIntent) -> String {
        switch intent {
        case .commitment: return "Commitment"
        case .flexibleTask: return "Task"
        case .ambiguous: return "Choose type"
        }
    }

    private func dismissKeyboard() {
        focus = nil
    }
}

private struct CaptureChip: Identifiable {
    var id: String
    var label: String
    var inferred: Bool
}

private struct FlowChips: View {
    let items: [CaptureChip]
    var onTap: (CaptureChip) -> Void

    var body: some View {
        ChipWrap(spacing: 8) {
            ForEach(items) { item in
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 4) {
                        Text(item.label)
                        if item.inferred {
                            Text("inferred")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.inferred ? "\(item.label), inferred" : item.label)
            }
        }
    }
}

private struct ChipWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? 0, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        let limit = width > 0 ? width : CGFloat.greatestFiniteMagnitude
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > limit, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: max(maxX, width), height: y + rowHeight), positions)
    }
}
