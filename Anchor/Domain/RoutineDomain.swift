import Foundation

enum ActivityEventKind: String, Codable, Equatable {
    case completed
    case corrected
}

enum CurrentActivityKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case notThis
    case cleaning
    case outside
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notThis: return "Not this"
        case .cleaning: return "Cleaning"
        case .outside: return "Outside"
        case .other: return "Something else"
        }
    }
}

enum HistoryEventContext: String, Codable, Equatable {
    case scheduled
    case completed
    case moved
    case deferred
    case corrected
    case logged

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .moved: return "Moved"
        case .deferred: return "Deferred"
        case .corrected: return "Corrected"
        case .logged: return "Logged"
        }
    }
}

struct CurrentActivityOverride: Equatable, Sendable {
    var timeBlockID: UUID?
    var exceptionID: UUID?
    var plannedTitle: String
    var actualTitle: String
    var actualKind: CurrentActivityKind
}

enum RoutineCatalog {
    static let skincareSteps: [(key: String, title: String, category: TaskCategory, isOptional: Bool, sortIndex: Int)] = [
        ("skincare.am.cleanser", "Cleanser", .skincareAM, false, 0),
        ("skincare.am.vitaminc", "Vitamin C (optional)", .skincareAM, true, 1),
        ("skincare.am.moisturizer", "Moisturizer", .skincareAM, false, 2),
        ("skincare.am.sunscreen", "Sunscreen", .skincareAM, false, 3),
        ("skincare.pm.cleanser", "Cleanser", .skincarePM, false, 0),
        ("skincare.pm.moisturizer", "Moisturizer", .skincarePM, false, 1),
    ]
}
