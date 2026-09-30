import Foundation
import TagReportingCore

/// In-progress report draft — single-slot autosave payload (T9).
struct ReportDraft: Codable, Equatable, Sendable {
    var clientUUID: UUID?
    var reporterEmpID: String?
    var storeID: UUID?
    var locationID: UUID?
    var locationOtherText: String?
    var foundBucket: FoundBucket?
    var foundAt: Date?
    var foundWindowStart: Date?
    var foundWindowEnd: Date?
    var foundAtIsEstimate: Bool?
    var notes: String?
    var tags: [TagDraft]
    var photoLocalPath: String?
    var step: String

    init(
        clientUUID: UUID? = UUID(),
        reporterEmpID: String? = nil,
        storeID: UUID? = nil,
        locationID: UUID? = nil,
        locationOtherText: String? = nil,
        foundBucket: FoundBucket? = nil,
        foundAt: Date? = nil,
        foundWindowStart: Date? = nil,
        foundWindowEnd: Date? = nil,
        foundAtIsEstimate: Bool? = nil,
        notes: String? = nil,
        tags: [TagDraft] = [],
        photoLocalPath: String? = nil,
        step: String = "scan"
    ) {
        self.clientUUID = clientUUID
        self.reporterEmpID = reporterEmpID
        self.storeID = storeID
        self.locationID = locationID
        self.locationOtherText = locationOtherText
        self.foundBucket = foundBucket
        self.foundAt = foundAt
        self.foundWindowStart = foundWindowStart
        self.foundWindowEnd = foundWindowEnd
        self.foundAtIsEstimate = foundAtIsEstimate
        self.notes = notes
        self.tags = tags
        self.photoLocalPath = photoLocalPath
        self.step = step
    }
}

struct TagDraft: Codable, Equatable, Sendable {
    var id: UUID
    var tagBarcode: String?
    var itemCode: String?
    var size: String
    var colour: String
    var identifyMethod: IdentifyMethod
    var tagState: TagState?
    var itemName: String?

    init(
        id: UUID = UUID(),
        tagBarcode: String? = nil,
        itemCode: String? = nil,
        size: String = "",
        colour: String = "",
        identifyMethod: IdentifyMethod = .scan,
        tagState: TagState? = nil,
        itemName: String? = nil
    ) {
        self.id = id
        self.tagBarcode = tagBarcode
        self.itemCode = itemCode
        self.size = size
        self.colour = colour
        self.identifyMethod = identifyMethod
        self.tagState = tagState
        self.itemName = itemName
    }
}
