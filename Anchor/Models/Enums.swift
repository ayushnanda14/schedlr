import Foundation

enum AppMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case livingAlone
    case away

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .livingAlone: return "Living Alone"
        case .away: return "Away"
        }
    }
}

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum SplitDay: String, Codable, CaseIterable, Identifiable {
    case upperA
    case lowerA
    case upperB
    case lowerB
    case rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upperA: return "Upper A"
        case .lowerA: return "Lower A"
        case .upperB: return "Upper B"
        case .lowerB: return "Lower B"
        case .rest: return "Rest"
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case gym
    case skincareAM
    case skincarePM
    case nutrition
    case posture
    case sleep
}

enum SkincareActive: String, CaseIterable, Identifiable {
    case none
    case azelaicAcid = "azelaic acid"
    case adapalene
    case benzoylPeroxide = "benzoyl peroxide"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None tonight"
        case .azelaicAcid: return "Azelaic acid"
        case .adapalene: return "Adapalene"
        case .benzoylPeroxide: return "Benzoyl peroxide"
        }
    }

    var needsSpacing: Bool {
        self == .adapalene || self == .benzoylPeroxide
    }

    var storedValue: String? {
        self == .none ? nil : rawValue
    }

    static func fromStored(_ value: String?) -> SkincareActive {
        guard let value else { return .none }
        return SkincareActive(rawValue: value) ?? .none
    }
}

enum SyncStatus: String, Codable {
    case notSynced
    case synced
    case pendingUpload
    case pendingDelete
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case gym
    case skincare
    case periodicTasks
    case weight
    case schedule

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .gym: return "Gym"
        case .skincare: return "Skincare"
        case .periodicTasks: return "Periodic Tasks"
        case .weight: return "Weight"
        case .schedule: return "Schedule"
        }
    }
}
