import Foundation

enum SkincareRotation {
    /// Pre-select tonight's active. Strong actives (adapalene / BPO) get a spacing night.
    static func recommended(after last: SkincareActive) -> SkincareActive {
        if last.needsSpacing { return .azelaicAcid }
        switch last {
        case .none: return .azelaicAcid
        case .azelaicAcid: return .adapalene
        case .adapalene: return .benzoylPeroxide
        case .benzoylPeroxide: return .azelaicAcid
        }
    }
}
