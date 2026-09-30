import Foundation

public enum RepositoryError: Error, Equatable, Sendable {
    case notFound
    case validationFailed(String)
    case persistenceFailed(String)
    case conflict
    case unauthorized
    case unavailable
}

public protocol ReportRepository: Sendable {
    func saveReport(_ report: Report) async throws
    func fetchReport(clientUUID: UUID) async throws -> Report?
    func pendingSyncCount() async throws -> Int
}

public protocol ProductRefRepository: Sendable {
    func lookup(itemCode: String) async -> ProductRef?
    func searchByName(_ query: String) async -> [ProductRef]
}

public protocol LocationRepository: Sendable {
    func floors(for storeID: UUID) async throws -> [StoreFloor]
    func children(of parentID: UUID?) async throws -> [LocationNode]
    func node(id: UUID) async throws -> LocationNode?
    func isSeedReady() async -> Bool
}

public protocol StoreConfigRepository: Sendable {
    func storeProfile() async throws -> StoreProfile?
    func tradingHours(for storeID: UUID) async throws -> [TradingHours]
    func flagThresholdRules(for storeID: UUID) async throws -> [FlagThresholdRule]
}

public protocol SyncQueuePort: Sendable {
    func enqueue(clientUUID: UUID) async throws
    func pendingCount() async throws -> Int
    func triggerSyncIfNeeded() async
}

public protocol AuthSessionProviding: Sendable {
    var isAuthenticated: Bool { get async }
    func signOut() async
}

public protocol ReporterAttributionProviding: Sendable {
    var currentReporter: ReporterContext? { get async }
}

public protocol DashboardRepository: Sendable {
    // Declared for guardrail uniformity; the web dashboard is the loss-prevention surface.
}

public protocol EscalationRepository: Sendable {
    // Declared for guardrail uniformity; the web dashboard owns escalation.
}

public protocol DashboardAuthProviding: Sendable {
    func verifySupervisorPIN(_ pin: String) async -> Bool
    func verifyLPAdminPIN(_ pin: String) async -> Bool
}
