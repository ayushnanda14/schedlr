import Foundation

protocol SyncableRecord: AnyObject {
    var id: UUID { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var isDeleted: Bool { get set }
    var syncStatusRaw: String { get set }
}

extension SyncableRecord {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .notSynced }
        set { syncStatusRaw = newValue.rawValue }
    }

    func markDirty(at date: Date = Date()) {
        updatedAt = date
        if syncStatus != .pendingDelete {
            syncStatus = .notSynced
        }
    }

    func markDeleted(at date: Date = Date()) {
        isDeleted = true
        syncStatus = .pendingDelete
        updatedAt = date
    }
}
