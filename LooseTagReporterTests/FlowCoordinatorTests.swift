import Foundation
import Testing
import TagReportingCore
@testable import LooseTagReporter

struct FlowCoordinatorTests {
    @Test func happyPathTapBudget() {
        let taps = FlowTapMetrics.decisionTaps(
            choseNow: true,
            skippedPhoto: true,
            selectedTagStateOnScan: true
        )
        #expect(FlowTapMetrics.withinBudget(taps))
        #expect(taps == 2)
    }

    @Test @MainActor
    func offlineSubmitQueuesAndClearsDraft() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)
        let session = SessionStore()
        #expect(session.signIn(empID: "1234"))

        let binding = StoreBinding(
            storeID: UUID(uuidString: "a0000000-0000-4000-8000-000000000001")!,
            storeCode: "demo-store",
            isProductionBinding: true
        )
        let coordinator = ReportingFlowCoordinator(
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_700_000_000)),
            reportRepository: repo,
            itemResolver: ItemResolver(refs: StaticRefs()),
            storeBinding: binding,
            session: session,
            canSubmit: true
        )

        let identity = await ItemResolver(refs: StaticRefs()).resolve(
            itemCode: "2000101",
            colourCode: "30",
            sizeCode: "103"
        )
        await coordinator.applyIdentity(identity, tagState: .intact)
        await coordinator.chooseNow()
        await coordinator.skipPhoto()
        await coordinator.applyLocation(LocationSelection(locationID: UUID(), breadcrumb: ["GF", "SF", "Zone A"]))
        await coordinator.submit()

        #expect(coordinator.step == .confirmation)
        #expect(coordinator.lastSubmitOutcome == .queued)
        #expect(try outbox.pendingCount() == 1)
        #expect(try await repo.loadDraft() == nil)
    }

    @Test @MainActor
    func unboundStoreRefusesSubmit() async throws {
        let db = try DatabaseManager.inMemory()
        let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
        let outbox = Outbox(dbPool: db.dbPool)
        let repo = GRDBReportRepository(dbPool: db.dbPool, outbox: outbox, photoStore: photos)
        let session = SessionStore()
        _ = session.signIn(empID: "1234")

        let coordinator = ReportingFlowCoordinator(
            clock: FixedClock(date: Date()),
            reportRepository: repo,
            itemResolver: ItemResolver(refs: StaticRefs()),
            storeBinding: nil,
            session: session,
            canSubmit: false
        )

        await coordinator.applyIdentity(
            ItemResolver(refs: StaticRefs()).unidentified(tagBarcode: nil),
            tagState: .tornOff
        )
        await coordinator.chooseNow()
        await coordinator.skipPhoto()
        await coordinator.applyLocation(LocationSelection(locationID: UUID(), breadcrumb: ["x"]))
        await coordinator.submit()

        #expect(coordinator.step == .review)
        #expect(coordinator.submitError != nil)
        #expect(try outbox.pendingCount() == 0)
    }
}

private struct StaticRefs: ProductReferenceProviding {
    func product(itemCode: String) async -> ProductRef? {
        itemCode == "2000101"
            ? ProductRef(itemCode: "2000101", name: "Demo tee", category: "Tops")
            : nil
    }
    func colourName(code: String) async -> String? { nil }
    func size(articleField: String) async -> (code: String, label: String)? {
        articleField == "103" ? ("03", "M") : nil
    }
}
