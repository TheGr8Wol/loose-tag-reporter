import Foundation
import GRDB
import TagReportingCore

/// Adapts GRDB reference tables to `ProductReferenceProviding`.
final class GRDBProductReferenceAdapter: ProductReferenceProviding, @unchecked Sendable {
    private let products: GRDBProductRefRepository
    private let dbPool: DatabasePool
    private let lock = NSLock()
    private var colours: [String: String?] = [:]
    private var sizesByArticle: [String: (code: String, label: String)] = [:]
    private var loaded = false

    init(dbPool: DatabasePool, products: GRDBProductRefRepository) {
        self.dbPool = dbPool
        self.products = products
    }

    func warm() async throws {
        try await products.warmIndex()
        let colourRows = try await dbPool.read { db in
            try ColourCodeRecord.filter(Column("active") == true).fetchAll(db)
        }
        let sizeRows = try await dbPool.read { db in
            try SizeCodeRecord.filter(Column("active") == true).fetchAll(db)
        }
        lock.lock()
        colours = Dictionary(uniqueKeysWithValues: colourRows.map { ($0.code, $0.name) })
        sizesByArticle = Dictionary(uniqueKeysWithValues: sizeRows.map {
            ($0.articleField, (code: $0.code, label: $0.label))
        })
        loaded = true
        lock.unlock()
    }

    func product(itemCode: String) async -> ProductRef? {
        await products.lookup(itemCode: itemCode)
    }

    func colourName(code: String) async -> String? {
        await ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return colours[code] ?? nil
    }

    func size(articleField: String) async -> (code: String, label: String)? {
        await ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return sizesByArticle[articleField]
    }

    private func ensureLoaded() async {
        lock.lock()
        let ready = loaded
        lock.unlock()
        if !ready { try? await warm() }
    }
}
