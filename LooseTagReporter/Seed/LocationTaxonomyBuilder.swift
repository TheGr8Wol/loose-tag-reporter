import Foundation
import TagReportingCore

struct BuiltLocationNode: Sendable {
    var record: LocationNodeRecord
    var stableKey: String
}

enum LocationTaxonomyBuilder {
    /// Sales-floor template endpoints, identical for every store so "Zone B" means the same
    /// kind of place everywhere. Per-floor exclusions come from the store profile.
    private static let sfTemplate: [(code: String, label: String, isOther: Bool)] = [
        ("checkout", "Checkout", false),
        ("fitting_rooms", "Fitting Rooms", false),
        ("entrance", "Entrance", false),
        ("zone_a", "Zone A", false),
        ("zone_b", "Zone B", false),
        ("zone_c", "Zone C", false),
        ("zone_d", "Zone D", false),
        ("Other", "Other?", true),
    ]

    static func build(profile: SeedStoreProfile) -> (floors: [StoreFloorRecord], nodes: [LocationNodeRecord]) {
        guard UUID(uuidString: profile.id) != nil else {
            return ([], [])
        }
        // Keep store_id exactly as profile.id (UUID.uuidString is uppercase — SQLite FKs are case-sensitive).
        let storeIDString = profile.id

        var floors: [StoreFloorRecord] = []
        var nodes: [LocationNodeRecord] = []

        for floor in profile.floors.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let floorID = StableLocationID.uuid(
                storeCode: profile.storeCode,
                floorCode: floor.code,
                areaType: .sf,
                path: ["_floor"]
            )
            floors.append(StoreFloorRecord(
                id: floorID.uuidString.lowercased(),
                storeID: storeIDString,
                code: floor.code,
                label: floor.label,
                sortOrder: floor.sortOrder
            ))

            let excluded = Set(profile.sfExclusionsByFloor[floor.code] ?? [])

            for (index, endpoint) in sfTemplate.enumerated() {
                let active = !excluded.contains(endpoint.code)
                let endpointID = StableLocationID.uuid(
                    storeCode: profile.storeCode,
                    floorCode: floor.code,
                    areaType: .sf,
                    path: [endpoint.code]
                )
                let endpointIDString = endpointID.uuidString.lowercased()
                let floorIDString = floorID.uuidString.lowercased()
                nodes.append(LocationNodeRecord(
                    id: endpointIDString,
                    storeID: storeIDString,
                    floorID: floorIDString,
                    areaType: AreaType.sf.rawValue,
                    parentID: nil,
                    code: endpoint.code,
                    label: endpoint.label,
                    kind: SurveyNodeKind.endpoint.rawValue,
                    isOtherBucket: endpoint.isOther,
                    isTemplate: true,
                    sortOrder: index,
                    active: active
                ))

                if endpoint.code == "fitting_rooms" {
                    nodes.append(contentsOf: subLevels(
                        storeCode: profile.storeCode,
                        storeIDString: storeIDString,
                        floorIDString: floorIDString,
                        floorCode: floor.code,
                        areaType: .sf,
                        parentCode: "fitting_rooms",
                        parentIDString: endpointIDString,
                        children: [
                            ("booth", "Booth"),
                            ("corridor", "Corridor"),
                        ],
                        active: active
                    ))
                } else if endpoint.code == "checkout" {
                    nodes.append(contentsOf: subLevels(
                        storeCode: profile.storeCode,
                        storeIDString: storeIDString,
                        floorIDString: floorIDString,
                        floorCode: floor.code,
                        areaType: .sf,
                        parentCode: "checkout",
                        parentIDString: endpointIDString,
                        children: [
                            ("self_checkout", "Self-checkout"),
                            ("staffed", "Staffed till"),
                        ],
                        active: active
                    ))
                }
            }

            let rooms = profile.bohRoomsByFloor[floor.code] ?? []
            for (index, room) in rooms.enumerated() {
                let roomID = StableLocationID.uuid(
                    storeCode: profile.storeCode,
                    floorCode: floor.code,
                    areaType: .boh,
                    path: [room.code]
                )
                nodes.append(LocationNodeRecord(
                    id: roomID.uuidString.lowercased(),
                    storeID: storeIDString,
                    floorID: floorID.uuidString.lowercased(),
                    areaType: AreaType.boh.rawValue,
                    parentID: nil,
                    code: room.code,
                    label: room.label,
                    kind: SurveyNodeKind.endpoint.rawValue,
                    isOtherBucket: room.isOtherBucket,
                    isTemplate: false,
                    sortOrder: index,
                    active: true
                ))
            }
        }

        return (floors, nodes)
    }

    private static func subLevels(
        storeCode: String,
        storeIDString: String,
        floorIDString: String,
        floorCode: String,
        areaType: AreaType,
        parentCode: String,
        parentIDString: String,
        children: [(String, String)],
        active: Bool
    ) -> [LocationNodeRecord] {
        children.enumerated().map { index, child in
            let id = StableLocationID.uuid(
                storeCode: storeCode,
                floorCode: floorCode,
                areaType: areaType,
                path: [parentCode, child.0]
            )
            return LocationNodeRecord(
                id: id.uuidString.lowercased(),
                storeID: storeIDString,
                floorID: floorIDString,
                areaType: areaType.rawValue,
                parentID: parentIDString,
                code: child.0,
                label: child.1,
                kind: SurveyNodeKind.subLevel.rawValue,
                isOtherBucket: false,
                isTemplate: true,
                sortOrder: index,
                active: active
            )
        }
    }
}
