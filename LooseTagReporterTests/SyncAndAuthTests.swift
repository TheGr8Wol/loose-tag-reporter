import Foundation
import Testing
import UIKit
import TagReportingCore
@testable import LooseTagReporter

struct SyncEngineTests {
    @Test func doubleTriggerSingleFlights() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)
        let remote = MockRemoteReportStore()
        let reachability = MockReachability(initialStatus: .online)
        let engine = SyncEngine(
            dbPool: db.dbPool,
            remote: remote,
            photoStore: photos,
            reachability: reachability
        )

        let report = sampleReport()
        try await repo.saveReport(report)

        async let a: () = engine.triggerSyncIfNeeded()
        async let b: () = engine.triggerSyncIfNeeded()
        _ = await (a, b)

        #expect(await remote.reportCount() == 1)
        #expect(await remote.upserts(for: report.clientUUID) == 1)
        #expect(try outbox.pendingCount() == 0)
    }

    @Test func resumeAfterUpsertBeforePhoto() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)
        let remote = MockRemoteReportStore()
        await remote.configure(failAfterUpsertBeforePhoto: true)
        let reachability = MockReachability(initialStatus: .online)
        let engine = SyncEngine(
            dbPool: db.dbPool,
            remote: remote,
            photoStore: photos,
            reachability: reachability
        )

        var report = sampleReport()
        let photoID = UUID()
        // Tiny valid JPEG so sync refuses empty-bytes path (A4-L-002) while still testing resume.
        let jpeg = tinyJPEG()
        let url = try photos.writePhoto(clientUUID: report.clientUUID, photoID: photoID, imageData: jpeg)
        report.photos = [ReportPhoto(id: photoID, localPath: url.path, capturedAt: Date())]
        try await repo.saveReport(report)

        await engine.triggerSyncIfNeeded()
        #expect(try outbox.pendingCount() == 1)
        #expect(await remote.upserts(for: report.clientUUID) == 1)

        await engine.triggerSyncIfNeeded()
        #expect(try outbox.pendingCount() == 0)
        #expect(await remote.reportCount() == 1)
        // Second upsert is idempotent overwrite
        #expect(await remote.upserts(for: report.clientUUID) == 2)
    }

    @Test func offlineLeavesPending() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)
        let remote = MockRemoteReportStore()
        let reachability = MockReachability(initialStatus: .offline)
        let engine = SyncEngine(
            dbPool: db.dbPool,
            remote: remote,
            photoStore: photos,
            reachability: reachability
        )

        try await repo.saveReport(sampleReport())
        await engine.triggerSyncIfNeeded()

        #expect(try outbox.pendingCount() == 1)
        #expect(await remote.reportCount() == 0)
    }

    private func sampleReport() -> Report {
        let now = Date()
        return Report(
            storeID: UUID(uuidString: "a0000000-0000-4000-8000-000000000001")!,
            locationID: UUID(),
            foundTime: FoundTime(bucket: .now, resolvedAt: now, isEstimate: false),
            tags: [
                Tag(itemCode: "2000101", size: "03", colour: "30", identifyMethod: .scan, tagState: .intact),
            ],
            deviceID: "test",
            reporterEmpID: "1234",
            createdAt: now
        )
    }

    /// 1×1 JPEG for PhotoFileStore downscale path.
    private func tinyJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}

struct AuthTests {
    @Test func staffCodePolicyBounds() {
        #expect(StaffCodePolicy.isValid("1234"))
        #expect(StaffCodePolicy.isValid("12345678"))
        #expect(!StaffCodePolicy.isValid("123"))
        #expect(!StaffCodePolicy.isValid(String(repeating: "1", count: StaffCodePolicy.maxLength + 1)))
        #expect(!StaffCodePolicy.isValid("12ab"))
    }

    @Test func dashboardPINGate() async {
        // Test-only values; real PINs are provisioned out-of-band and never live in source.
        let auth = LocalDashboardAuth(salt: "test-salt", supervisorPIN: "1111", lpAdminPIN: "2222")
        #expect(await auth.verifySupervisorPIN("1111"))
        #expect(await auth.verifyLPAdminPIN("2222"))
        #expect(await auth.verifySupervisorPIN("0000") == false)
        #expect(await auth.verifyLPAdminPIN("1111") == false)
    }

    @Test func unprovisionedGateRefusesEverything() async {
        let auth = DenyAllDashboardAuth()
        #expect(await auth.verifySupervisorPIN("1111") == false)
        #expect(await auth.verifyLPAdminPIN("2222") == false)
    }

    @Test func constantTimeCompare() {
        #expect(LocalDashboardAuth.constantTimeEquals("abc", "abc"))
        #expect(!LocalDashboardAuth.constantTimeEquals("abc", "abd"))
        #expect(!LocalDashboardAuth.constantTimeEquals("abc", "ab"))
    }
}
