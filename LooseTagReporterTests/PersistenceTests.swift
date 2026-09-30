import Foundation
import GRDB
import Testing
import TagReportingCore
@testable import LooseTagReporter

struct PersistenceTests {
    @Test func saveReportOfflineRoundTrip() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)

        let report = makeSampleReport()
        try await repo.saveReport(report)

        let loaded = try await repo.fetchReport(clientUUID: report.clientUUID)
        #expect(loaded != nil)
        #expect(loaded?.tags.count == 1)
        #expect(loaded?.tags.first?.itemCode == nil) // unidentified
        #expect(loaded?.foundTime.windowStart != nil)
        #expect(try outbox.pendingCount() == 1)
    }

    @Test func draftAutosaveResume() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)

        var draft = ReportDraft(step: "when")
        draft.tags = [TagDraft(itemCode: "2000101", size: "103", colour: "30", tagState: .intact)]
        try await repo.saveDraft(draft)

        let loaded = try await repo.loadDraft()
        #expect(loaded?.step == "when")
        #expect(loaded?.tags.first?.itemCode == "2000101")

        try await repo.clearDraft()
        #expect(try await repo.loadDraft() == nil)
    }

    @Test func seedDemoStoreCounts() async throws {
        let db = try DatabaseManager.inMemory()
        // Seed CSVs/JSON ship in the app host bundle.
        let service = SeedImportService(dbPool: db.dbPool, bundle: .main)

        _ = try await service.ensureSeeded()
        #expect(try await service.isSeedReady())

        let products = try await db.dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM product_ref WHERE active = 1") ?? 0
        }
        let colours = try await db.dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM colour_code WHERE active = 1") ?? 0
        }
        let sizes = try await db.dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM size_code WHERE active = 1") ?? 0
        }
        #expect(products == SeedImportService.expectedProductCount)
        #expect(colours == SeedImportService.expectedColourCount)
        #expect(sizes == SeedImportService.expectedSizeCount)

        let known = try await db.dbPool.read { db in
            try ProductRefRecord.fetchOne(db, key: "2000101")
        }
        #expect(known?.name == "Demo Cotton Crew T-Shirt")

        // Quoted CSV field with an embedded comma survives parsing.
        let quoted = try await db.dbPool.read { db in
            try ProductRefRecord.fetchOne(db, key: "2000601")
        }
        #expect(quoted?.name == "Demo Ankle Socks, 3 Pack")

        let unknown = try await db.dbPool.read { db in
            try ProductRefRecord.fetchOne(db, key: "2999999")
        }
        #expect(unknown == nil)
    }

    private func makeSampleReport() -> Report {
        let now = Date()
        return Report(
            storeID: UUID(uuidString: "a0000000-0000-4000-8000-000000000001")!,
            locationID: UUID(),
            foundTime: FoundTime(
                bucket: .now,
                resolvedAt: now,
                windowStart: now.addingTimeInterval(-300),
                windowEnd: now,
                isEstimate: false
            ),
            tags: [
                Tag(
                    itemCode: nil,
                    size: "",
                    colour: "",
                    identifyMethod: .unidentified,
                    tagState: .intact
                ),
            ],
            deviceID: "test-device",
            reporterEmpID: "123456",
            createdAt: now
        )
    }
}

private final class BundleToken {}
