import Foundation
import GRDB

/// Single GRDB `DatabasePool` for outbox + reference/config (`app.sqlite`).
final class DatabaseManager: @unchecked Sendable {
    let dbPool: DatabasePool
    let directoryURL: URL

    init(directoryURL: URL? = nil) throws {
        let dir = try directoryURL ?? Self.defaultDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dbURL = dir.appendingPathComponent("app.sqlite")
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbPool = try DatabasePool(path: dbURL.path, configuration: config)
        try AppDatabase.migrator.migrate(dbPool)

        // Data Protection: completeUntilFirstUserAuthentication on DB + WAL + SHM.
        try Self.applyDataProtection(to: dbURL)
        let wal = URL(fileURLWithPath: dbURL.path + "-wal")
        let shm = URL(fileURLWithPath: dbURL.path + "-shm")
        try? Self.applyDataProtection(to: wal)
        try? Self.applyDataProtection(to: shm)

        self.directoryURL = dir
    }

    /// In-memory pool for tests.
    static func inMemory() throws -> DatabaseManager {
        let mgr = try DatabaseManager(directoryURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("ltr-test-\(UUID().uuidString)", isDirectory: true))
        return mgr
    }

    private static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("LooseTagReporter", isDirectory: true)
    }

    static func applyDataProtection(to url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}
