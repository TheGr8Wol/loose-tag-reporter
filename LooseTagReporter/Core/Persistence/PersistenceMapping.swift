import Foundation
import TagReportingCore

enum PersistenceMapping {
    static func reportRecord(from report: Report) -> ReportRecord {
        ReportRecord(
            id: report.id.uuidString,
            clientUUID: report.clientUUID.uuidString,
            storeID: report.storeID.uuidString,
            locationID: report.locationID.uuidString,
            locationOtherText: report.locationOtherText,
            foundBucket: report.foundTime.bucket.rawValue,
            foundAt: report.foundTime.resolvedAt,
            foundAtIsEstimate: report.foundTime.isEstimate,
            foundWindowStart: report.foundTime.windowStart,
            foundWindowEnd: report.foundTime.windowEnd,
            notes: report.notes,
            status: report.status.rawValue,
            tagCount: report.tagCount,
            deviceID: report.deviceID,
            reporterEmpID: report.reporterEmpID,
            appVersion: report.appVersion,
            createdAt: report.createdAt,
            syncedAt: report.syncedAt,
            syncState: report.syncState.rawValue
        )
    }

    static func tagRecords(from report: Report) -> [TagRecord] {
        report.tags.enumerated().map { index, tag in
            TagRecord(
                id: tag.id.uuidString,
                reportID: report.id.uuidString,
                tagBarcode: tag.tagBarcode,
                itemCode: tag.itemCode,
                size: tag.size,
                colour: tag.colour,
                identifyMethod: tag.identifyMethod.rawValue,
                tagState: tag.tagState.rawValue,
                itemName: tag.itemName,
                itemCategory: tag.itemCategory,
                styleFamilyID: tag.styleFamilyID,
                sortOrder: index
            )
        }
    }

    static func photoRecords(from report: Report) -> [ReportPhotoRecord] {
        report.photos.map { photo in
            ReportPhotoRecord(
                id: photo.id.uuidString,
                reportID: report.id.uuidString,
                localPath: photo.localPath,
                storagePath: photo.storagePath,
                capturedAt: photo.capturedAt
            )
        }
    }

    static func report(
        from record: ReportRecord,
        tags: [TagRecord],
        photos: [ReportPhotoRecord]
    ) throws -> Report {
        guard let id = UUID(uuidString: record.id),
              let clientUUID = UUID(uuidString: record.clientUUID),
              let storeID = UUID(uuidString: record.storeID),
              let locationID = UUID(uuidString: record.locationID),
              let bucket = FoundBucket(rawValue: record.foundBucket),
              let status = ReportStatus(rawValue: record.status),
              let syncState = SyncState(rawValue: record.syncState)
        else {
            throw RepositoryError.persistenceFailed("Corrupt report record")
        }

        let foundTime = FoundTime(
            bucket: bucket,
            resolvedAt: record.foundAt,
            windowStart: record.foundWindowStart,
            windowEnd: record.foundWindowEnd,
            isEstimate: record.foundAtIsEstimate
        )

        let mappedTags: [Tag] = try tags.sorted { $0.sortOrder < $1.sortOrder }.map { tag in
            guard let tagID = UUID(uuidString: tag.id),
                  let method = IdentifyMethod(rawValue: tag.identifyMethod),
                  let state = TagState(rawValue: tag.tagState)
            else {
                throw RepositoryError.persistenceFailed("Corrupt tag record")
            }
            return Tag(
                id: tagID,
                tagBarcode: tag.tagBarcode,
                itemCode: tag.itemCode,
                size: tag.size,
                colour: tag.colour,
                identifyMethod: method,
                tagState: state,
                itemName: tag.itemName,
                itemCategory: tag.itemCategory,
                styleFamilyID: tag.styleFamilyID
            )
        }

        let mappedPhotos: [ReportPhoto] = try photos.map { photo in
            guard let photoID = UUID(uuidString: photo.id) else {
                throw RepositoryError.persistenceFailed("Corrupt photo record")
            }
            return ReportPhoto(
                id: photoID,
                localPath: photo.localPath,
                storagePath: photo.storagePath,
                capturedAt: photo.capturedAt
            )
        }

        return Report(
            id: id,
            clientUUID: clientUUID,
            storeID: storeID,
            locationID: locationID,
            locationOtherText: record.locationOtherText,
            foundTime: foundTime,
            notes: record.notes,
            status: status,
            tags: mappedTags,
            photos: mappedPhotos,
            deviceID: record.deviceID,
            reporterEmpID: record.reporterEmpID,
            appVersion: record.appVersion,
            createdAt: record.createdAt,
            syncedAt: record.syncedAt,
            syncState: syncState
        )
    }
}
