import Foundation
import GRDB
import TagReportingCore

enum SyncEngineError: Error, Equatable {
    case missingPhotoBytes(photoID: UUID)
}

/// Single-flight FIFO sync engine. Proven against `MockRemoteReportStore` before Supabase.
actor SyncEngine {
    private let dbPool: DatabasePool
    private let remote: any RemoteReportStore
    private let photoStore: PhotoFileStore
    private let reachability: any ReachabilityProviding

    private var isRunning = false
    private var runRequested = false

    init(
        dbPool: DatabasePool,
        remote: any RemoteReportStore,
        photoStore: PhotoFileStore,
        reachability: any ReachabilityProviding
    ) {
        self.dbPool = dbPool
        self.remote = remote
        self.photoStore = photoStore
        self.reachability = reachability
    }

    /// Concurrent triggers coalesce into a single run.
    func triggerSyncIfNeeded() async {
        if isRunning {
            runRequested = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        repeat {
            runRequested = false
            await drainOnce()
        } while runRequested
    }

    private func drainOnce() async {
        guard await reachability.status == .online else { return }

        let pending: [OutboxRecord]
        do {
            pending = try await dbPool.read { db in
                try OutboxRecord.order(Column("created_at")).fetchAll(db)
            }
        } catch {
            return
        }

        for item in pending {
            guard let clientUUID = UUID(uuidString: item.clientUUID) else { continue }
            do {
                try await syncOne(clientUUID: clientUUID)
            } catch {
                try? await dbPool.write { db in
                    var row = item
                    row.attempts += 1
                    row.lastError = String(describing: error)
                    try row.update(db)
                    try db.execute(
                        sql: "UPDATE report SET sync_state = ? WHERE client_uuid = ?",
                        arguments: [SyncState.failed.rawValue, clientUUID.uuidString]
                    )
                }
                return
            }
        }
    }

    private func syncOne(clientUUID: UUID) async throws {
        let report: Report = try await dbPool.read { db in
            guard let record = try ReportRecord
                .filter(Column("client_uuid") == clientUUID.uuidString)
                .fetchOne(db)
            else {
                throw RepositoryError.notFound
            }
            let tags = try TagRecord.filter(Column("report_id") == record.id).fetchAll(db)
            let photos = try ReportPhotoRecord.filter(Column("report_id") == record.id).fetchAll(db)
            return try PersistenceMapping.report(from: record, tags: tags, photos: photos)
        }

        try await dbPool.write { db in
            try db.execute(
                sql: "UPDATE report SET sync_state = ? WHERE client_uuid = ?",
                arguments: [SyncState.syncing.rawValue, clientUUID.uuidString]
            )
        }

        try await remote.upsertReport(RemoteReportPayload(report: report))

        for photo in report.photos {
            let data: Data
            if let path = photo.localPath, FileManager.default.fileExists(atPath: path) {
                data = try Data(contentsOf: URL(fileURLWithPath: path))
            } else {
                // Prefer deterministic PhotoFileStore path when draft path missing.
                let fallback = photoStore.path(clientUUID: report.clientUUID, photoID: photo.id)
                if FileManager.default.fileExists(atPath: fallback.path) {
                    data = try Data(contentsOf: fallback)
                } else {
                    throw SyncEngineError.missingPhotoBytes(photoID: photo.id)
                }
            }
            guard !data.isEmpty else {
                throw SyncEngineError.missingPhotoBytes(photoID: photo.id)
            }
            try await remote.uploadPhoto(
                storeID: report.storeID,
                clientUUID: report.clientUUID,
                photoID: photo.id,
                data: data
            )
        }

        try await dbPool.write { db in
            try db.execute(
                sql: """
                UPDATE report SET sync_state = ?, synced_at = ? WHERE client_uuid = ?;
                DELETE FROM outbox WHERE client_uuid = ?;
                """,
                arguments: [
                    SyncState.synced.rawValue,
                    Date(),
                    clientUUID.uuidString,
                    clientUUID.uuidString,
                ]
            )
        }
    }
}
