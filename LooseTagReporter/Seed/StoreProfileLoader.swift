import Foundation

struct SeedStoreProfile: Codable, Sendable {
    var id: String
    var storeCode: String
    var name: String
    var isMultiFloor: Bool
    var seedVersion: String
    var floors: [SeedFloor]
    var sfExclusionsByFloor: [String: [String]]
    var bohRoomsByFloor: [String: [SeedRoom]]
}

struct SeedFloor: Codable, Sendable {
    var code: String
    var label: String
    var sortOrder: Int
}

struct SeedRoom: Codable, Sendable {
    var code: String
    var label: String
    var isOther: Bool?

    var isOtherBucket: Bool { isOther == true }
}

enum StoreProfileLoader {
    static func load(from url: URL) throws -> SeedStoreProfile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SeedStoreProfile.self, from: data)
    }

    static func loadBundled(bundle: Bundle = .main) throws -> SeedStoreProfile {
        let candidates = [
            bundle.url(forResource: "store_profile_demo", withExtension: "json"),
            bundle.url(forResource: "store_profile_demo", withExtension: "json", subdirectory: "Seed"),
            bundle.url(forResource: "store_profile_demo", withExtension: "json", subdirectory: "Fixtures/Seed"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw SeedError.missingResource("store_profile_demo.json")
        }
        return try load(from: url)
    }
}

enum SeedError: Error, Equatable {
    case missingResource(String)
    case invalidProfile(String)
}
