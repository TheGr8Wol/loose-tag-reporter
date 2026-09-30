import Foundation
import Observation
import TagReportingCore

/// Composition root — hand-rolled DI, no framework (see docs/ADR-001-architecture.md).
@MainActor
@Observable
final class AppContainer: Dependencies {
    let config: AppConfig
    let featureFlags: FeatureFlags
    let managedConfig: ManagedAppConfig
    let storeBinding: StoreBinding?
    let clock: any NowProviding
    let remoteReportStore: any RemoteReportStore
    let reachability: any ReachabilityProviding
    let sessionStore: SessionStore
    let dashboardAuth: any DashboardAuthProviding

    let databaseManager: DatabaseManager?
    let photoStore: PhotoFileStore?
    let outbox: Outbox?
    let reportRepository: GRDBReportRepository?
    let productRefRepository: GRDBProductRefRepository?
    let productRefs: GRDBProductReferenceAdapter?
    let locationRepository: GRDBLocationRepository?
    let storeConfigRepository: GRDBStoreConfigRepository?
    let seedService: SeedImportService?
    let syncEngine: SyncEngine?
    let persistenceError: String?

    var requiresDevBindingBanner: Bool {
        guard let binding = storeBinding else { return true }
        return !binding.isProductionBinding
    }

    var canSubmitReports: Bool {
        storeBinding?.isProductionBinding == true
    }

    init(
        config: AppConfig = .current,
        featureFlags: FeatureFlags = .releaseDefaults,
        managedConfig: ManagedAppConfig = .load(),
        clock: any NowProviding = SystemClock(),
        remoteReportStore: (any RemoteReportStore)? = nil,
        reachability: (any ReachabilityProviding)? = nil,
        sessionStore: SessionStore? = nil,
        dashboardAuth: any DashboardAuthProviding = DenyAllDashboardAuth(),
        openDatabase: Bool = true
    ) {
        self.config = config
        self.featureFlags = featureFlags
        self.managedConfig = managedConfig
        self.storeBinding = StoreBinding.resolve(appConfig: config, managed: managedConfig)
        self.clock = clock
        self.sessionStore = sessionStore ?? SessionStore()
        self.dashboardAuth = dashboardAuth

        let resolvedReachability = reachability ?? Reachability()
        self.reachability = resolvedReachability

        if openDatabase {
            do {
                let db = try DatabaseManager()
                let photos = try PhotoFileStore(applicationSupportURL: db.directoryURL)
                let box = Outbox(dbPool: db.dbPool)
                let seed = SeedImportService(dbPool: db.dbPool)
                let products = GRDBProductRefRepository(dbPool: db.dbPool)
                let refs = GRDBProductReferenceAdapter(dbPool: db.dbPool, products: products)
                let remote = remoteReportStore ?? MockRemoteReportStore()
                let sync = SyncEngine(
                    dbPool: db.dbPool,
                    remote: remote,
                    photoStore: photos,
                    reachability: resolvedReachability
                )
                self.remoteReportStore = remote
                self.databaseManager = db
                self.photoStore = photos
                self.outbox = box
                self.reportRepository = GRDBReportRepository(dbPool: db.dbPool, outbox: box, photoStore: photos)
                self.productRefRepository = products
                self.productRefs = refs
                self.locationRepository = GRDBLocationRepository(dbPool: db.dbPool, seed: seed)
                self.storeConfigRepository = GRDBStoreConfigRepository(dbPool: db.dbPool)
                self.seedService = seed
                self.syncEngine = sync
                self.persistenceError = nil
            } catch {
                self.remoteReportStore = remoteReportStore ?? MockRemoteReportStore()
                self.databaseManager = nil
                self.photoStore = nil
                self.outbox = nil
                self.reportRepository = nil
                self.productRefRepository = nil
                self.productRefs = nil
                self.locationRepository = nil
                self.storeConfigRepository = nil
                self.seedService = nil
                self.syncEngine = nil
                self.persistenceError = error.localizedDescription
            }
        } else {
            self.remoteReportStore = remoteReportStore ?? MockRemoteReportStore()
            self.databaseManager = nil
            self.photoStore = nil
            self.outbox = nil
            self.reportRepository = nil
            self.productRefRepository = nil
            self.productRefs = nil
            self.locationRepository = nil
            self.storeConfigRepository = nil
            self.seedService = nil
            self.syncEngine = nil
            self.persistenceError = nil
        }
    }
}

@MainActor
enum PreviewContainer {
    static func make() -> AppContainer {
        AppContainer(
            managedConfig: ManagedAppConfig(
                storeID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                storeCode: "demo-store-preview",
                staffCodeLength: nil,
                telemetryEnabled: nil
            ),
            clock: FixedClock(date: Date(timeIntervalSince1970: 1_700_000_000)),
            remoteReportStore: MockRemoteReportStore(),
            reachability: MockReachability(initialStatus: .online),
            openDatabase: false
        )
    }
}

protocol Dependencies {
    var config: AppConfig { get }
    var featureFlags: FeatureFlags { get }
    var storeBinding: StoreBinding? { get }
    var clock: any NowProviding { get }
    var requiresDevBindingBanner: Bool { get }
    var canSubmitReports: Bool { get }
}

private struct SystemClock: NowProviding {
    var now: Date { Date() }
}

struct MockReachability: ReachabilityProviding {
    private(set) var status: ReachabilityStatus

    init(initialStatus: ReachabilityStatus = .offline) {
        self.status = initialStatus
    }

    func startMonitoring() async {}
    func stopMonitoring() async {}
}

struct FixedClock: NowProviding {
    let date: Date
    var now: Date { date }
}
