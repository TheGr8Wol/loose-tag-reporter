import Foundation
import TagReportingCore

/// In-memory remote used to prove sync idempotency before Supabase (T15 / RISK AREA 2).
actor MockRemoteReportStore: RemoteReportStore {
    struct State: Sendable {
        var reports: [UUID: Report] = [:]
        var photos: Set<String> = []
        var upsertCount: [UUID: Int] = [:]
        var photoUploadCount: [String: Int] = [:]
        var failNextUpsert = false
        var failNextPhoto = false
        var failAfterUpsertBeforePhoto = false
    }

    private(set) var state = State()

    func reset() {
        state = State()
    }

    func configure(
        failNextUpsert: Bool = false,
        failNextPhoto: Bool = false,
        failAfterUpsertBeforePhoto: Bool = false
    ) {
        state.failNextUpsert = failNextUpsert
        state.failNextPhoto = failNextPhoto
        state.failAfterUpsertBeforePhoto = failAfterUpsertBeforePhoto
    }

    func upsertReport(_ payload: RemoteReportPayload) async throws {
        if state.failNextUpsert {
            state.failNextUpsert = false
            throw RepositoryError.unavailable
        }
        let id = payload.report.clientUUID
        state.reports[id] = payload.report
        state.upsertCount[id, default: 0] += 1
        if state.failAfterUpsertBeforePhoto {
            state.failAfterUpsertBeforePhoto = false
            throw RepositoryError.unavailable
        }
    }

    func uploadPhoto(storeID: UUID, clientUUID: UUID, photoID: UUID, data: Data) async throws {
        if state.failNextPhoto {
            state.failNextPhoto = false
            throw RepositoryError.unavailable
        }
        let key = "\(storeID.uuidString.lowercased())/\(clientUUID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
        state.photos.insert(key)
        state.photoUploadCount[key, default: 0] += 1
    }

    func reportCount() -> Int { state.reports.count }
    func upserts(for clientUUID: UUID) -> Int { state.upsertCount[clientUUID] ?? 0 }
}
