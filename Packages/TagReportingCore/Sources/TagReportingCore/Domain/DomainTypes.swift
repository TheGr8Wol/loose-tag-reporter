import Foundation

public struct Tag: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var tagBarcode: String?
    public var itemCode: String?
    public var size: String
    public var colour: String
    public var identifyMethod: IdentifyMethod
    public var tagState: TagState
    public var itemName: String?
    public var itemCategory: String?
    public var styleFamilyID: String?

    public init(
        id: UUID = UUID(),
        tagBarcode: String? = nil,
        itemCode: String? = nil,
        size: String,
        colour: String,
        identifyMethod: IdentifyMethod,
        tagState: TagState,
        itemName: String? = nil,
        itemCategory: String? = nil,
        styleFamilyID: String? = nil
    ) {
        self.id = id
        self.tagBarcode = tagBarcode
        self.itemCode = itemCode
        self.size = size
        self.colour = colour
        self.identifyMethod = identifyMethod
        self.tagState = tagState
        self.itemName = itemName
        self.itemCategory = itemCategory
        self.styleFamilyID = styleFamilyID
    }
}

public struct ReportPhoto: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var localPath: String?
    public var storagePath: String?
    public var capturedAt: Date

    public init(id: UUID = UUID(), localPath: String? = nil, storagePath: String? = nil, capturedAt: Date) {
        self.id = id
        self.localPath = localPath
        self.storagePath = storagePath
        self.capturedAt = capturedAt
    }
}

public struct FoundTime: Equatable, Sendable {
    public var bucket: FoundBucket
    public var resolvedAt: Date
    public var windowStart: Date?
    public var windowEnd: Date?
    public var isEstimate: Bool

    public init(
        bucket: FoundBucket,
        resolvedAt: Date,
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        isEstimate: Bool
    ) {
        self.bucket = bucket
        self.resolvedAt = resolvedAt
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.isEstimate = isEstimate
    }
}

public struct Report: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let clientUUID: UUID
    public var storeID: UUID
    public var locationID: UUID
    public var locationOtherText: String?
    public var foundTime: FoundTime
    public var notes: String?
    public var status: ReportStatus
    public var tags: [Tag]
    public var photos: [ReportPhoto]
    public var deviceID: String
    public var reporterEmpID: String
    public var appVersion: String?
    public var createdAt: Date
    public var syncedAt: Date?
    public var syncState: SyncState

    public var tagCount: Int { tags.count }

    public init(
        id: UUID = UUID(),
        clientUUID: UUID = UUID(),
        storeID: UUID,
        locationID: UUID,
        locationOtherText: String? = nil,
        foundTime: FoundTime,
        notes: String? = nil,
        status: ReportStatus = .submitted,
        tags: [Tag],
        photos: [ReportPhoto] = [],
        deviceID: String,
        reporterEmpID: String,
        appVersion: String? = nil,
        createdAt: Date,
        syncedAt: Date? = nil,
        syncState: SyncState = .pending
    ) {
        self.id = id
        self.clientUUID = clientUUID
        self.storeID = storeID
        self.locationID = locationID
        self.locationOtherText = locationOtherText
        self.foundTime = foundTime
        self.notes = notes
        self.status = status
        self.tags = tags
        self.photos = photos
        self.deviceID = deviceID
        self.reporterEmpID = reporterEmpID
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.syncedAt = syncedAt
        self.syncState = syncState
    }
}

public struct LocationNode: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var storeID: UUID
    public var floorID: UUID?
    public var areaType: AreaType
    public var parentID: UUID?
    public var code: String
    public var label: String
    public var kind: SurveyNodeKind
    public var isOtherBucket: Bool
    public var isTemplate: Bool
    public var sortOrder: Int
    public var active: Bool

    public init(
        id: UUID,
        storeID: UUID,
        floorID: UUID? = nil,
        areaType: AreaType,
        parentID: UUID? = nil,
        code: String,
        label: String,
        kind: SurveyNodeKind,
        isOtherBucket: Bool = false,
        isTemplate: Bool = false,
        sortOrder: Int = 0,
        active: Bool = true
    ) {
        self.id = id
        self.storeID = storeID
        self.floorID = floorID
        self.areaType = areaType
        self.parentID = parentID
        self.code = code
        self.label = label
        self.kind = kind
        self.isOtherBucket = isOtherBucket
        self.isTemplate = isTemplate
        self.sortOrder = sortOrder
        self.active = active
    }
}

public struct StoreFloor: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var storeID: UUID
    public var code: String
    public var label: String
    public var sortOrder: Int

    public init(id: UUID, storeID: UUID, code: String, label: String, sortOrder: Int = 0) {
        self.id = id
        self.storeID = storeID
        self.code = code
        self.label = label
        self.sortOrder = sortOrder
    }
}

public struct StoreProfile: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var code: String
    public var name: String
    public var isMultiFloor: Bool
    public var floors: [StoreFloor]

    public init(id: UUID, code: String, name: String, isMultiFloor: Bool, floors: [StoreFloor] = []) {
        self.id = id
        self.code = code
        self.name = name
        self.isMultiFloor = isMultiFloor
        self.floors = floors
    }
}

public struct ProductRef: Equatable, Sendable {
    public var itemCode: String
    public var name: String
    public var category: String?

    public init(itemCode: String, name: String, category: String? = nil) {
        self.itemCode = itemCode
        self.name = name
        self.category = category
    }
}

public struct Variant: Equatable, Sendable {
    public var itemCode: String
    public var sizeCode: String
    public var colourCode: String
    public var colourName: String?

    public init(itemCode: String, sizeCode: String, colourCode: String, colourName: String? = nil) {
        self.itemCode = itemCode
        self.sizeCode = sizeCode
        self.colourCode = colourCode
        self.colourName = colourName
    }
}

public struct LocationSelection: Equatable, Sendable {
    public var locationID: UUID
    public var breadcrumb: [String]
    public var otherText: String?
    public var isOtherBucket: Bool

    public init(locationID: UUID, breadcrumb: [String], otherText: String? = nil, isOtherBucket: Bool = false) {
        self.locationID = locationID
        self.breadcrumb = breadcrumb
        self.otherText = otherText
        self.isOtherBucket = isOtherBucket
    }
}

public struct TagIdentityResolution: Equatable, Sendable {
    public var itemCode: String?
    public var size: String
    public var colour: String
    public var identifyMethod: IdentifyMethod
    public var tagBarcode: String?
    public var itemName: String?
    public var itemCategory: String?
    public var confidence: Double?

    public init(
        itemCode: String?,
        size: String,
        colour: String,
        identifyMethod: IdentifyMethod,
        tagBarcode: String? = nil,
        itemName: String? = nil,
        itemCategory: String? = nil,
        confidence: Double? = nil
    ) {
        self.itemCode = itemCode
        self.size = size
        self.colour = colour
        self.identifyMethod = identifyMethod
        self.tagBarcode = tagBarcode
        self.itemName = itemName
        self.itemCategory = itemCategory
        self.confidence = confidence
    }
}

public struct ReporterContext: Equatable, Sendable {
    public var empID: String
    public var capturedAt: Date

    public init(empID: String, capturedAt: Date) {
        self.empID = empID
        self.capturedAt = capturedAt
    }
}

public struct TradingHours: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var storeID: UUID
    public var weekday: Int
    public var openTime: String
    public var closeTime: String

    public init(id: UUID = UUID(), storeID: UUID, weekday: Int, openTime: String, closeTime: String) {
        self.id = id
        self.storeID = storeID
        self.weekday = weekday
        self.openTime = openTime
        self.closeTime = closeTime
    }
}

public struct FlagThresholdRule: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var storeID: UUID
    public var scope: FlagThresholdScope
    public var scopeRefID: UUID?
    public var tradingPhase: TradingPhase
    public var areaType: AreaType?
    public var minTagCount: Int

    public init(
        id: UUID = UUID(),
        storeID: UUID,
        scope: FlagThresholdScope,
        scopeRefID: UUID? = nil,
        tradingPhase: TradingPhase,
        areaType: AreaType? = nil,
        minTagCount: Int
    ) {
        self.id = id
        self.storeID = storeID
        self.scope = scope
        self.scopeRefID = scopeRefID
        self.tradingPhase = tradingPhase
        self.areaType = areaType
        self.minTagCount = minTagCount
    }
}
