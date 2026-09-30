import Foundation

public protocol TagIdentityResolving: Sendable {
    func resolve(from scanResult: TagIdentityResolution) async -> TagIdentityResolution
}

public protocol LocationSurveyProviding: Sendable {
    func selection(for locationID: UUID) async throws -> LocationSelection?
}

public protocol NowProviding: Sendable {
    var now: Date { get }
}

public struct RemoteReportPayload: Equatable, Sendable {
    public var report: Report

    public init(report: Report) {
        self.report = report
    }
}

public protocol RemoteReportStore: Sendable {
    func upsertReport(_ payload: RemoteReportPayload) async throws
    func uploadPhoto(
        storeID: UUID,
        clientUUID: UUID,
        photoID: UUID,
        data: Data
    ) async throws
}

public enum ReachabilityStatus: Sendable {
    case offline
    case online
}

public protocol ReachabilityProviding: Sendable {
    var status: ReachabilityStatus { get async }
    func startMonitoring() async
    func stopMonitoring() async
}

public protocol RemoteStorage: Sendable {
    func put(path: String, data: Data) async throws
}
