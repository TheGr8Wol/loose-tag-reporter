import Foundation
import GRDB

struct StoreRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "store"
    var id: String
    var code: String
    var name: String
    var isMultiFloor: Bool
    enum CodingKeys: String, CodingKey {
        case id, code, name
        case isMultiFloor = "is_multi_floor"
    }
}

struct StoreFloorRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "store_floor"
    var id: String
    var storeID: String
    var code: String
    var label: String
    var sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case id, code, label
        case storeID = "store_id"
        case sortOrder = "sort_order"
    }
}

struct LocationNodeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "location_node"
    var id: String
    var storeID: String
    var floorID: String?
    var areaType: String
    var parentID: String?
    var code: String
    var label: String
    var kind: String
    var isOtherBucket: Bool
    var isTemplate: Bool
    var sortOrder: Int
    var active: Bool
    enum CodingKeys: String, CodingKey {
        case id, code, label, kind, active
        case storeID = "store_id"
        case floorID = "floor_id"
        case areaType = "area_type"
        case parentID = "parent_id"
        case isOtherBucket = "is_other_bucket"
        case isTemplate = "is_template"
        case sortOrder = "sort_order"
    }
}

struct ProductRefRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "product_ref"
    var itemCode: String
    var name: String
    var category: String?
    var active: Bool
    enum CodingKeys: String, CodingKey {
        case name, category, active
        case itemCode = "item_code"
    }
}

struct ColourCodeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "colour_code"
    var code: String
    var name: String?
    var active: Bool
}

struct SizeCodeRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "size_code"
    var code: String
    var articleField: String
    var label: String
    var active: Bool
    enum CodingKeys: String, CodingKey {
        case code, label, active
        case articleField = "article_field"
    }
}

struct TradingHoursRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "trading_hours"
    var id: String
    var storeID: String
    var weekday: Int
    var openTime: String
    var closeTime: String
    enum CodingKeys: String, CodingKey {
        case id, weekday
        case storeID = "store_id"
        case openTime = "open_time"
        case closeTime = "close_time"
    }
}

struct FlagThresholdRuleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "flag_threshold_rule"
    var id: String
    var storeID: String
    var scope: String
    var scopeRefID: String?
    var tradingPhase: String
    var areaType: String?
    var minTagCount: Int
    enum CodingKeys: String, CodingKey {
        case id, scope
        case storeID = "store_id"
        case scopeRefID = "scope_ref_id"
        case tradingPhase = "trading_phase"
        case areaType = "area_type"
        case minTagCount = "min_tag_count"
    }
}

struct ReportRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "report"
    var id: String
    var clientUUID: String
    var storeID: String
    var locationID: String
    var locationOtherText: String?
    var foundBucket: String
    var foundAt: Date
    var foundAtIsEstimate: Bool
    var foundWindowStart: Date?
    var foundWindowEnd: Date?
    var notes: String?
    var status: String
    var tagCount: Int
    var deviceID: String
    var reporterEmpID: String
    var appVersion: String?
    var createdAt: Date
    var syncedAt: Date?
    var syncState: String
    enum CodingKeys: String, CodingKey {
        case id, notes, status
        case clientUUID = "client_uuid"
        case storeID = "store_id"
        case locationID = "location_id"
        case locationOtherText = "location_other_text"
        case foundBucket = "found_bucket"
        case foundAt = "found_at"
        case foundAtIsEstimate = "found_at_is_estimate"
        case foundWindowStart = "found_window_start"
        case foundWindowEnd = "found_window_end"
        case tagCount = "tag_count"
        case deviceID = "device_id"
        case reporterEmpID = "reporter_emp_id"
        case appVersion = "app_version"
        case createdAt = "created_at"
        case syncedAt = "synced_at"
        case syncState = "sync_state"
    }
}

struct TagRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tag"
    var id: String
    var reportID: String
    var tagBarcode: String?
    var itemCode: String?
    var size: String
    var colour: String
    var identifyMethod: String
    var tagState: String
    var itemName: String?
    var itemCategory: String?
    var styleFamilyID: String?
    var sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case id, size, colour
        case reportID = "report_id"
        case tagBarcode = "tag_barcode"
        case itemCode = "item_code"
        case identifyMethod = "identify_method"
        case tagState = "tag_state"
        case itemName = "item_name"
        case itemCategory = "item_category"
        case styleFamilyID = "style_family_id"
        case sortOrder = "sort_order"
    }
}

struct ReportPhotoRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "report_photo"
    var id: String
    var reportID: String
    var localPath: String?
    var storagePath: String?
    var capturedAt: Date
    enum CodingKeys: String, CodingKey {
        case id
        case reportID = "report_id"
        case localPath = "local_path"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
    }
}

struct OutboxRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "outbox"
    var clientUUID: String
    var createdAt: Date
    var attempts: Int
    var lastError: String?
    enum CodingKeys: String, CodingKey {
        case attempts
        case clientUUID = "client_uuid"
        case createdAt = "created_at"
        case lastError = "last_error"
    }
}

struct ReportDraftRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "report_draft"
    var slot: Int
    var payloadJSON: String
    var updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case slot
        case payloadJSON = "payload_json"
        case updatedAt = "updated_at"
    }
}

struct SeedMetaRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "seed_meta"
    var key: String
    var value: String
}
