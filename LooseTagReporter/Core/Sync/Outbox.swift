import Foundation
import GRDB
import TagReportingCore

final class Outbox: Sendable {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func enqueue(clientUUID: UUID, createdAt: Date = Date()) throws {
        try dbPool.write { db in
            try OutboxRecord(
                clientUUID: clientUUID.uuidString,
                createdAt: createdAt,
                attempts: 0,
                lastError: nil
            ).insert(db, onConflict: .ignore)
        }
    }

    func pendingCount() throws -> Int {
        try dbPool.read { db in
            try OutboxRecord.fetchCount(db)
        }
    }

    func pendingFIFO() throws -> [OutboxRecord] {
        try dbPool.read { db in
            try OutboxRecord
                .order(Column("created_at"))
                .fetchAll(db)
        }
    }
}
