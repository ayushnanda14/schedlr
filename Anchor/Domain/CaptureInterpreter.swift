import Foundation

struct CaptureInterpreter {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func interpret(_ text: String, now: Date, preserving previous: CaptureDraft? = nil) -> CaptureResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        var working = trimmed
        var inferred: Set<CaptureField> = [.day]
        var day = calendar.startOfDay(for: now)
        var startHour: Int?
        var startMinute: Int?
        var durationMinutes: Int?
        var deadline: Date?
        var priority = PlanTaskPriority.normal
        var intentHint: CaptureIntent?

        if let extracted = extractDeadline(&working, now: now) {
            deadline = extracted
            inferred.insert(.deadline)
        }
        if let extracted = extractDuration(&working) {
            durationMinutes = extracted
            inferred.insert(.duration)
        }
        if let extracted = extractClock(&working) {
            startHour = extracted.hour
            startMinute = extracted.minute
            inferred.insert(.startTime)
        }
        if let extracted = extractDay(&working, now: now) {
            day = extracted
            inferred.insert(.day)
        }
        if let extracted = extractPriority(&working) {
            priority = extracted
            inferred.insert(.priority)
        }
        if let extracted = extractExplicitIntent(&working) {
            intentHint = extracted
            inferred.insert(.intent)
        }

        let title = collapseWhitespace(working)
        guard !title.isEmpty else {
            return .invalid("A schedule item needs a title.")
        }

        if startHour != nil, durationMinutes == nil {
            durationMinutes = 30
            inferred.insert(.duration)
        }

        let intent = intentHint ?? inferIntent(title: title, hasStartTime: startHour != nil)
        if intentHint == nil {
            inferred.insert(.intent)
        }

        var draft = CaptureDraft(
            rawText: text,
            title: title,
            day: calendar.startOfDay(for: day),
            startHour: startHour,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            deadline: deadline,
            priority: priority,
            intent: intent,
            inferred: inferred,
            userEdited: []
        )

        if let previous, previous.rawText != text {
            draft = draft.mergingUserEdits(from: previous)
        } else if let previous, previous.rawText == text {
            return .parsed(previous)
        }

        if let previous, previous.exceptionKind != nil {
            draft.exceptionKind = previous.exceptionKind
        }

        return .parsed(draft)
    }

    func inferredActivityKind(from title: String) -> ActivityKind {
        let text = title.lowercased()
        if containsAny(text, ["gym", "workout", "exercise", "run", "lift"]) { return .exercise }
        if containsAny(text, ["meeting", "standup", "work"]) { return .work }
        if containsAny(text, ["lunch", "dinner", "breakfast", "brunch"]) { return .meal }
        if containsAny(text, ["sleep", "nap"]) { return .sleep }
        if containsAny(text, ["commute", "train", "flight", "drive"]) { return .commute }
        if containsAny(text, ["outside", "outing", "errand"]) { return .outing }
        if containsAny(text, ["match", "dentist", "doctor", "appointment", "interview"]) { return .event }
        return .personal
    }

    // MARK: - Extraction

    private func extractDuration(_ text: inout String) -> Int? {
        let pattern = #"(?i)(?:for\s+)?(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b"#
        guard let match = firstMatch(pattern, in: text) else { return nil }
        let amount = Double(match.group(1, in: text) ?? "") ?? 0
        let unit = (match.group(2, in: text) ?? "").lowercased()
        remove(match.range, from: &text)
        if unit.hasPrefix("h") {
            return max(1, Int((amount * 60).rounded()))
        }
        return max(1, Int(amount.rounded()))
    }

    private func extractClock(_ text: inout String) -> (hour: Int, minute: Int)? {
        let meridiem = #"(?i)(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#
        if let match = firstMatch(meridiem, in: text),
           let parsed = clock(from: match, in: text, defaultMeridiem: match.group(3, in: text)) {
            remove(match.range, from: &text)
            return parsed
        }

        let atHour = #"(?i)\bat\s+(\d{1,2})(?::(\d{2}))?\b"#
        if let match = firstMatch(atHour, in: text),
           let parsed = clock(from: match, in: text, defaultMeridiem: nil) {
            remove(match.range, from: &text)
            return parsed
        }

        let twentyFour = #"(?i)\b(\d{1,2}):(\d{2})\b"#
        if let match = firstMatch(twentyFour, in: text),
           let parsed = clock(from: match, in: text, defaultMeridiem: nil) {
            remove(match.range, from: &text)
            return parsed
        }
        return nil
    }

    private func extractDay(_ text: inout String, now: Date) -> Date? {
        let nextWeekday = #"(?i)\bnext\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#
        if let match = firstMatch(nextWeekday, in: text),
           let name = match.group(1, in: text),
           let date = weekday(named: name, now: now, skipToday: true) {
            remove(match.range, from: &text)
            return date
        }

        let named = #"(?i)\b(today|tomorrow|tonight|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#
        if let match = firstMatch(named, in: text), let token = match.group(1, in: text)?.lowercased() {
            remove(match.range, from: &text)
            switch token {
            case "today", "tonight":
                return calendar.startOfDay(for: now)
            case "tomorrow":
                return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            default:
                return weekday(named: token, now: now, skipToday: false)
            }
        }
        return nil
    }

    private func extractPriority(_ text: inout String) -> PlanTaskPriority? {
        if let match = firstMatch(#"(?i)\burgent\b"#, in: text) {
            remove(match.range, from: &text)
            return .urgent
        }
        if let match = firstMatch(#"(?i)\bhigh[- ]priority\b"#, in: text) {
            remove(match.range, from: &text)
            return .high
        }
        if let match = firstMatch(#"(?i)\blow[- ]priority\b"#, in: text) {
            remove(match.range, from: &text)
            return .low
        }
        return nil
    }

    private func extractExplicitIntent(_ text: inout String) -> CaptureIntent? {
        if let match = firstMatch(#"(?i)\b(fixed|commitment)\b"#, in: text) {
            remove(match.range, from: &text)
            return .commitment
        }
        if let match = firstMatch(#"(?i)\b(flexible|task)\b"#, in: text) {
            remove(match.range, from: &text)
            return .flexibleTask
        }
        return nil
    }

    private func extractDeadline(_ text: inout String, now: Date) -> Date? {
        let pattern = #"(?i)\b(?:due|by|deadline)\s+(today|tomorrow|tonight|next\s+(?:sunday|monday|tuesday|wednesday|thursday|friday|saturday)|sunday|monday|tuesday|wednesday|thursday|friday|saturday)(?:\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?"#
        guard let match = firstMatch(pattern, in: text), let token = match.group(1, in: text) else { return nil }
        remove(match.range, from: &text)

        var day = calendar.startOfDay(for: now)
        let lowered = token.lowercased()
        if lowered == "tomorrow" {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        } else if lowered.hasPrefix("next ") {
            let name = String(lowered.dropFirst(5))
            day = weekday(named: name, now: now, skipToday: true) ?? day
        } else if lowered != "today", lowered != "tonight" {
            day = weekday(named: lowered, now: now, skipToday: false) ?? day
        }

        if let hourText = match.group(2, in: text), let hour = Int(hourText) {
            let minute = Int(match.group(3, in: text) ?? "0") ?? 0
            let parsed = normalizeHour(hour, minute: minute, meridiem: match.group(4, in: text))
            return calendar.date(bySettingHour: parsed.hour, minute: parsed.minute, second: 0, of: day)
        }
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)
    }

    private func inferIntent(title: String, hasStartTime: Bool) -> CaptureIntent {
        let text = title.lowercased()
        let commitmentTerms = ["dentist", "doctor", "appointment", "meeting", "interview", "flight", "match", "gym", "class"]
        let taskTerms = ["laundry", "buy", "call", "email", "clean", "pay", "review", "pack", "need to"]
        let looksCommitment = containsAny(text, commitmentTerms)
        let looksTask = containsAny(text, taskTerms)

        if looksCommitment && !looksTask { return .commitment }
        if looksTask && !looksCommitment { return .flexibleTask }
        if looksCommitment && looksTask { return .ambiguous }
        if hasStartTime { return .ambiguous }
        return .flexibleTask
    }

    // MARK: - Calendar helpers

    private func weekday(named name: String, now: Date, skipToday: Bool) -> Date? {
        let map = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        guard let weekday = map[name.lowercased()] else { return nil }
        let today = calendar.startOfDay(for: now)
        let current = calendar.component(.weekday, from: today)
        var delta = weekday - current
        if delta < 0 || (delta == 0 && skipToday) { delta += 7 }
        if delta == 0 && skipToday { delta = 7 }
        return calendar.date(byAdding: .day, value: delta, to: today)
    }

    private func clock(from match: NSTextCheckingResult, in text: String, defaultMeridiem: String?) -> (hour: Int, minute: Int)? {
        guard let hourText = match.group(1, in: text), let hour = Int(hourText) else { return nil }
        let minute = Int(match.group(2, in: text) ?? "0") ?? 0
        return normalizeHour(hour, minute: minute, meridiem: defaultMeridiem)
    }

    private func normalizeHour(_ hour: Int, minute: Int, meridiem: String?) -> (hour: Int, minute: Int) {
        var value = hour
        let period = meridiem?.lowercased()
        if period == "am" {
            if value == 12 { value = 0 }
        } else if period == "pm" {
            if value != 12 { value += 12 }
        }
        return (min(max(value, 0), 23), min(max(minute, 0), 59))
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

    private func collapseWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range)
    }

    private func remove(_ range: NSRange, from text: inout String) {
        guard let swiftRange = Range(range, in: text) else { return }
        text.replaceSubrange(swiftRange, with: " ")
    }
}

private extension NSTextCheckingResult {
    func group(_ index: Int, in text: String) -> String? {
        guard index < numberOfRanges else { return nil }
        let range = self.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
