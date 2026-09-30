import Foundation
import GRDB
import TagReportingCore

final class GRDBProductRefRepository: ProductRefRepository, @unchecked Sendable {
    private let dbPool: DatabasePool
    private let lock = NSLock()
    private var index: [String: ProductRef] = [:]
    private var loaded = false

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func warmIndex() async throws {
        let rows = try await dbPool.read { db in
            try ProductRefRecord.filter(Column("active") == true).fetchAll(db)
        }
        lock.lock()
        index = Dictionary(uniqueKeysWithValues: rows.map {
            ($0.itemCode, ProductRef(itemCode: $0.itemCode, name: $0.name, category: $0.category))
        })
        loaded = true
        lock.unlock()
    }

    func lookup(itemCode: String) async -> ProductRef? {
        await ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return index[itemCode]
    }

    func searchByName(_ query: String) async -> [ProductRef] {
        await ensureLoaded()
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return index.values
            .filter { $0.name.lowercased().contains(q) }
            .sorted { $0.name < $1.name }
    }

    private func ensureLoaded() async {
        lock.lock()
        let ready = loaded
        lock.unlock()
        if !ready {
            try? await warmIndex()
        }
    }
}

final class GRDBLocationRepository: LocationRepository, @unchecked Sendable {
    private let dbPool: DatabasePool
    private let seed: SeedImportService

    init(dbPool: DatabasePool, seed: SeedImportService) {
        self.dbPool = dbPool
        self.seed = seed
    }

    /// Seed persists UUID text lowercase; SQLite string equality is case-sensitive (A3-L-001).
    private static func sqlUUID(_ id: UUID) -> String {
        id.uuidString.lowercased()
    }

    func floors(for storeID: UUID) async throws -> [StoreFloor] {
        try await dbPool.read { db in
            try StoreFloorRecord
                .filter(Column("store_id") == Self.sqlUUID(storeID))
                .order(Column("sort_order"))
                .fetchAll(db)
                .compactMap { rec -> StoreFloor? in
                    guard let id = UUID(uuidString: rec.id),
                          let sid = UUID(uuidString: rec.storeID) else { return nil }
                    return StoreFloor(id: id, storeID: sid, code: rec.code, label: rec.label, sortOrder: rec.sortOrder)
                }
        }
    }

    func children(of parentID: UUID?) async throws -> [LocationNode] {
        try await dbPool.read { db in
            let records: [LocationNodeRecord]
            if let parentID {
                records = try LocationNodeRecord
                    .filter(Column("parent_id") == Self.sqlUUID(parentID) && Column("active") == true)
                    .order(Column("sort_order"))
                    .fetchAll(db)
            } else {
                records = try LocationNodeRecord
                    .filter(Column("parent_id") == nil && Column("active") == true)
                    .order(Column("sort_order"))
                    .fetchAll(db)
            }
            return records.compactMap(Self.mapNode)
        }
    }

    func node(id: UUID) async throws -> LocationNode? {
        try await dbPool.read { db in
            guard let rec = try LocationNodeRecord.fetchOne(db, key: Self.sqlUUID(id)) else { return nil }
            return Self.mapNode(rec)
        }
    }

    func isSeedReady() async -> Bool {
        (try? await seed.isSeedReady()) ?? false
    }

    private static func mapNode(_ rec: LocationNodeRecord) -> LocationNode? {
        guard let id = UUID(uuidString: rec.id),
              let storeID = UUID(uuidString: rec.storeID),
              let area = AreaType(rawValue: rec.areaType),
              let kind = SurveyNodeKind(rawValue: rec.kind)
        else { return nil }
        return LocationNode(
            id: id,
            storeID: storeID,
            floorID: rec.floorID.flatMap(UUID.init(uuidString:)),
            areaType: area,
            parentID: rec.parentID.flatMap(UUID.init(uuidString:)),
            code: rec.code,
            label: rec.label,
            kind: kind,
            isOtherBucket: rec.isOtherBucket,
            isTemplate: rec.isTemplate,
            sortOrder: rec.sortOrder,
            active: rec.active
        )
    }
}

final class GRDBStoreConfigRepository: StoreConfigRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func storeProfile() async throws -> StoreProfile? {
        try await dbPool.read { db in
            guard let store = try StoreRecord.fetchOne(db) else { return nil }
            guard let id = UUID(uuidString: store.id) else { return nil }
            let floors = try StoreFloorRecord
                .filter(Column("store_id") == store.id)
                .order(Column("sort_order"))
                .fetchAll(db)
                .compactMap { rec -> StoreFloor? in
                    guard let fid = UUID(uuidString: rec.id),
                          let sid = UUID(uuidString: rec.storeID) else { return nil }
                    return StoreFloor(id: fid, storeID: sid, code: rec.code, label: rec.label, sortOrder: rec.sortOrder)
                }
            return StoreProfile(
                id: id,
                code: store.code,
                name: store.name,
                isMultiFloor: store.isMultiFloor,
                floors: floors
            )
        }
    }

    func tradingHours(for storeID: UUID) async throws -> [TradingHours] {
        let key = storeID.uuidString.lowercased()
        return try await dbPool.read { db in
            try TradingHoursRecord
                .filter(Column("store_id") == key)
                .order(Column("weekday"))
                .fetchAll(db)
                .compactMap { rec in
                    guard let id = UUID(uuidString: rec.id) else { return nil }
                    return TradingHours(
                        id: id,
                        storeID: storeID,
                        weekday: rec.weekday,
                        openTime: rec.openTime,
                        closeTime: rec.closeTime
                    )
                }
        }
    }

    func flagThresholdRules(for storeID: UUID) async throws -> [FlagThresholdRule] {
        let key = storeID.uuidString.lowercased()
        return try await dbPool.read { db in
            try FlagThresholdRuleRecord
                .filter(Column("store_id") == key)
                .fetchAll(db)
                .compactMap { rec in
                    guard let id = UUID(uuidString: rec.id),
                          let scope = FlagThresholdScope(rawValue: rec.scope),
                          let phase = TradingPhase(rawValue: rec.tradingPhase)
                    else { return nil }
                    return FlagThresholdRule(
                        id: id,
                        storeID: storeID,
                        scope: scope,
                        scopeRefID: rec.scopeRefID.flatMap(UUID.init(uuidString:)),
                        tradingPhase: phase,
                        areaType: rec.areaType.flatMap(AreaType.init(rawValue:)),
                        minTagCount: rec.minTagCount
                    )
                }
        }
    }
}
