import Foundation
import GRDB
import TagReportingCore

final class SeedImportService: @unchecked Sendable {
    static let seedVersionKey = "seed_version"
    // Row counts of the bundled synthetic Demo Store seed (Resources/Seed).
    static let expectedProductCount = 24
    static let expectedColourCount = 14
    static let expectedSizeCount = 6

    private let dbPool: DatabasePool
    private let bundle: Bundle

    init(dbPool: DatabasePool, bundle: Bundle = .main) {
        self.dbPool = dbPool
        self.bundle = bundle
    }

    /// Idempotent first-run / refresh seed. Soft-deactivates removed rows; never deletes.
    @discardableResult
    func ensureSeeded() async throws -> Bool {
        let profile = try StoreProfileLoader.loadBundled(bundle: bundle)
        let productCSV = try loadCSV("product_ref_demo")
        let colourCSV = try loadCSV("colour_codes")
        let sizeCSV = try loadCSV("size_codes")
        let hoursCSV = try loadCSV("store_trading_hours")

        try await dbPool.write { db in
            let existing = try String.fetchOne(
                db,
                sql: "SELECT value FROM seed_meta WHERE key = ?",
                arguments: [Self.seedVersionKey]
            )

            // Always upsert — re-run is idempotent.
            try self.upsertStore(profile, db: db)
            try self.upsertTaxonomy(profile, db: db)
            try self.upsertProducts(productCSV, db: db)
            try self.upsertColours(colourCSV, db: db)
            try self.upsertSizes(sizeCSV, db: db)
            try self.upsertTradingHours(hoursCSV, storeID: profile.id, db: db)
            try self.upsertFlagDefaults(storeID: profile.id, db: db)

            try SeedMetaRecord(key: Self.seedVersionKey, value: profile.seedVersion).save(db)
            try SeedMetaRecord(key: "seeded_at", value: ISO8601DateFormatter().string(from: Date())).save(db)

            _ = existing // retained for future version-diff soft-deactivate
        }
        return true
    }

    func isSeedReady() async throws -> Bool {
        try await dbPool.read { db in
            let products = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM product_ref WHERE active = 1") ?? 0
            let colours = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM colour_code WHERE active = 1") ?? 0
            let sizes = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM size_code WHERE active = 1") ?? 0
            let nodes = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM location_node") ?? 0
            return products >= Self.expectedProductCount
                && colours >= Self.expectedColourCount
                && sizes >= Self.expectedSizeCount
                && nodes > 0
        }
    }

    // MARK: - Private

    private func loadCSV(_ name: String) throws -> String {
        let candidates = [
            bundle.url(forResource: name, withExtension: "csv"),
            bundle.url(forResource: name, withExtension: "csv", subdirectory: "Seed"),
            bundle.url(forResource: name, withExtension: "csv", subdirectory: "Fixtures/Seed"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw SeedError.missingResource("\(name).csv")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func upsertStore(_ profile: SeedStoreProfile, db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO store (id, code, name, is_multi_floor) VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              code = excluded.code,
              name = excluded.name,
              is_multi_floor = excluded.is_multi_floor
            """,
            arguments: [profile.id, profile.storeCode, profile.name, profile.isMultiFloor]
        )
    }

    private func upsertTaxonomy(_ profile: SeedStoreProfile, db: Database) throws {
        let (floors, nodes) = LocationTaxonomyBuilder.build(profile: profile)
        guard !floors.isEmpty else {
            throw SeedError.invalidProfile("Taxonomy builder produced no floors")
        }
        guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM store WHERE id = ?", arguments: [profile.id]) == 1 else {
            throw SeedError.invalidProfile("Store missing before taxonomy upsert")
        }
        let incomingIDs = Set(nodes.map(\.id))

        for floor in floors {
            try db.execute(
                sql: """
                INSERT INTO store_floor (id, store_id, code, label, sort_order) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  store_id = excluded.store_id,
                  code = excluded.code,
                  label = excluded.label,
                  sort_order = excluded.sort_order
                """,
                arguments: [floor.id, floor.storeID, floor.code, floor.label, floor.sortOrder]
            )
        }
        for node in nodes {
            try db.execute(
                sql: """
                INSERT INTO location_node (
                  id, store_id, floor_id, area_type, parent_id, code, label, kind,
                  is_other_bucket, is_template, sort_order, active
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  store_id = excluded.store_id,
                  floor_id = excluded.floor_id,
                  area_type = excluded.area_type,
                  parent_id = excluded.parent_id,
                  code = excluded.code,
                  label = excluded.label,
                  kind = excluded.kind,
                  is_other_bucket = excluded.is_other_bucket,
                  is_template = excluded.is_template,
                  sort_order = excluded.sort_order,
                  active = excluded.active
                """,
                arguments: [
                    node.id, node.storeID, node.floorID, node.areaType, node.parentID,
                    node.code, node.label, node.kind, node.isOtherBucket, node.isTemplate,
                    node.sortOrder, node.active,
                ]
            )
        }

        let existing = try LocationNodeRecord.fetchAll(db)
        for node in existing where !incomingIDs.contains(node.id) {
            try db.execute(sql: "UPDATE location_node SET active = 0 WHERE id = ?", arguments: [node.id])
        }
    }

    private func upsertProducts(_ csv: String, db: Database) throws {
        let rows = CSVSeedParser.rows(from: csv)
        let codes = Set(rows.compactMap { $0["item_code"] })
        for row in rows {
            guard let code = row["item_code"], let name = row["name"] else { continue }
            try ProductRefRecord(
                itemCode: code,
                name: name,
                category: row["category"],
                active: true
            ).save(db)
        }
        let existing = try ProductRefRecord.fetchAll(db)
        for rec in existing where !codes.contains(rec.itemCode) {
            var d = rec
            d.active = false
            try d.update(db)
        }
    }

    private func upsertColours(_ csv: String, db: Database) throws {
        let rows = CSVSeedParser.rows(from: csv)
        let codes = Set(rows.compactMap { $0["colour_code"] })
        for row in rows {
            guard let code = row["colour_code"] else { continue }
            let name = row["colour_name"].flatMap { $0.isEmpty ? nil : $0 }
            try ColourCodeRecord(code: code, name: name, active: true).save(db)
        }
        let existing = try ColourCodeRecord.fetchAll(db)
        for rec in existing where !codes.contains(rec.code) {
            var d = rec
            d.active = false
            try d.update(db)
        }
    }

    private func upsertSizes(_ csv: String, db: Database) throws {
        let rows = CSVSeedParser.rows(from: csv)
        let codes = Set(rows.compactMap { $0["size_code"] })
        for row in rows {
            guard let code = row["size_code"],
                  let field = row["article_field"],
                  let label = row["size_label"]
            else { continue }
            try SizeCodeRecord(code: code, articleField: field, label: label, active: true).save(db)
        }
        let existing = try SizeCodeRecord.fetchAll(db)
        for rec in existing where !codes.contains(rec.code) {
            var d = rec
            d.active = false
            try d.update(db)
        }
    }

    private func upsertTradingHours(_ csv: String, storeID: String, db: Database) throws {
        let weekdayMap: [String: Int] = [
            "Monday": 1, "Tuesday": 2, "Wednesday": 3, "Thursday": 4,
            "Friday": 5, "Saturday": 6, "Sunday": 7,
        ]
        for row in CSVSeedParser.rows(from: csv) {
            guard let day = row["weekday"],
                  let weekday = weekdayMap[day],
                  let open = row["open"],
                  let close = row["close"]
            else { continue }
            let id = StableLocationID.uuid(forStableKey: "trading/\(storeID)/\(weekday)").uuidString
            try TradingHoursRecord(
                id: id,
                storeID: storeID,
                weekday: weekday,
                openTime: open,
                closeTime: close
            ).save(db)
        }
    }

    private func upsertFlagDefaults(storeID: String, db: Database) throws {
        // Area-scoped defaults: minimum tags in one report before it is flagged for review,
        // per (trading phase, area). ILLUSTRATIVE VALUES ONLY — a real deployment sets these
        // per store with its loss-prevention team; more specific scopes override these.
        let defaults: [(TradingPhase, AreaType?, Int, String)] = [
            (.trading, .boh, 1, "boh_any"),
            (.preOpen, .boh, 1, "boh_pre"),
            (.postClose, .boh, 1, "boh_post"),
            (.trading, .sf, 2, "sf_trading"),
            (.preOpen, .sf, 3, "sf_pre"),
            (.postClose, .sf, 4, "sf_post"),
        ]
        for (phase, area, minCount, slug) in defaults {
            let id = StableLocationID.uuid(forStableKey: "flag/\(storeID)/\(slug)").uuidString
            try FlagThresholdRuleRecord(
                id: id,
                storeID: storeID,
                scope: FlagThresholdScope.area.rawValue,
                scopeRefID: nil,
                tradingPhase: phase.rawValue,
                areaType: area?.rawValue,
                minTagCount: minCount
            ).save(db)
        }
    }
}
