import Foundation

struct UndoToken: Identifiable, Equatable {
    enum Kind: Equatable {
        case checklist(UUID)
        case periodicTask(UUID)
        case proposal(PlanProposal)
        case scheduleShift(item: TodayTimelineItem, beforeStart: Date?, beforeEnd: Date?)
    }

    var id: UUID
    var message: String
    var kind: Kind

    init(id: UUID = UUID(), message: String, kind: Kind) {
        self.id = id
        self.message = message
        self.kind = kind
    }
}
