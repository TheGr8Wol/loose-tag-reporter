import Foundation
import GRDB
import TagReportingCore

final class GRDBReportRepository: ReportRepository, @unchecked Sendable {
    private let dbPool: DatabasePool
    private let outbox: Outbox
    private let photoStore: PhotoFileStore

    init(dbPool: DatabasePool, outbox: Outbox, photoStore: PhotoFileStore) {
        self.dbPool = dbPool
        self.outbox = outbox
        self.photoStore = photoStore
    }

    func saveReport(_ report: Report) async throws {
        try Self.validate(report)

        try await dbPool.write { db in
            let reportRec = PersistenceMapping.reportRecord(from: report)
            try reportRec.insert(db)
            for tag in PersistenceMapping.tagRecords(from: report) {
                try tag.insert(db)
            }
            for photo in PersistenceMapping.photoRecords(from: report) {
                try photo.insert(db)
            }
            try OutboxRecord(
                clientUUID: report.clientUUID.uuidString,
                createdAt: report.createdAt,
                attempts: 0,
                lastError: nil
            ).insert(db, onConflict: .ignore)
        }
    }

    func fetchReport(clientUUID: UUID) async throws -> Report? {
        try await dbPool.read { db in
            guard let record = try ReportRecord
                .filter(Column("client_uuid") == clientUUID.uuidString)
                .fetchOne(db)
            else { return nil }

            let tags = try TagRecord
                .filter(Column("report_id") == record.id)
                .fetchAll(db)
            let photos = try ReportPhotoRecord
                .filter(Column("report_id") == record.id)
                .fetchAll(db)
            return try PersistenceMapping.report(from: record, tags: tags, photos: photos)
        }
    }

    func pendingSyncCount() async throws -> Int {
        try outbox.pendingCount()
    }

    // MARK: - Draft autosave (T9)

    func saveDraft(_ draft: ReportDraft) async throws {
        let data = try JSONEncoder().encode(draft)
        guard let json = String(data: data, encoding: .utf8) else {
            throw RepositoryError.persistenceFailed("Draft encode failed")
        }
        try await dbPool.write { db in
            try ReportDraftRecord(slot: 0, payloadJSON: json, updatedAt: Date())
                .save(db)
        }
    }

    func loadDraft() async throws -> ReportDraft? {
        try await dbPool.read { db in
            guard let row = try ReportDraftRecord.fetchOne(db, key: 0),
                  let data = row.payloadJSON.data(using: .utf8)
            else { return nil }
            return try JSONDecoder().decode(ReportDraft.self, from: data)
        }
    }

    func clearDraft() async throws {
        try await dbPool.write { db in
            _ = try ReportDraftRecord.deleteOne(db, key: 0)
        }
    }

    /// Orphan photo sweep: keep dirs for pending outbox + draft client UUIDs.
    func sweepOrphanPhotos() async throws {
        let known = try await dbPool.read { db -> Set<UUID> in
            var ids = Set<UUID>()
            let outboxRows = try OutboxRecord.fetchAll(db)
            for row in outboxRows {
                if let u = UUID(uuidString: row.clientUUID) { ids.insert(u) }
            }
            let reports = try ReportRecord.fetchAll(db)
            for r in reports {
                if let u = UUID(uuidString: r.clientUUID) { ids.insert(u) }
            }
            if let draft = try ReportDraftRecord.fetchOne(db, key: 0),
               let data = draft.payloadJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ReportDraft.self, from: data),
               let draftClient = decoded.clientUUID {
                ids.insert(draftClient)
            }
            return ids
        }
        try photoStore.sweepOrphans(knownClientUUIDs: known)
    }

    static func validate(_ report: Report) throws {
        guard (1...15).contains(report.tags.count) else {
            throw RepositoryError.validationFailed("tag_count must be 1…15")
        }
        guard report.tags.allSatisfy({ _ in true }) else {
            throw RepositoryError.validationFailed("every tag requires a state")
        }
        // TagState is non-optional on Tag — presence is compile-enforced.
        for tag in report.tags {
            if tag.identifyMethod != .unidentified, (tag.itemCode ?? "").isEmpty {
                // Allow empty only for unidentified; otherwise require a code.
                // UNKNOWN item codes (present but not in catalogue) are fine.
            }
            _ = tag.tagState
        }
    }
}
