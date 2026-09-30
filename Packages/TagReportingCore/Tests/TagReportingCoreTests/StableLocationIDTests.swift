import Foundation
import Testing
@testable import TagReportingCore

struct StableLocationIDTests {
    /// Frozen golden vectors for the synthetic Demo Store. The backend seed generator and any
    /// other client must reproduce these exactly. Values were cross-checked against Python's
    /// `uuid.uuid5(UUID("7c9e6679-7425-40de-944b-e07fc1f90ae7"), key)`.
    private static let goldenVectors: [(key: String, uuid: String)] = [
        ("demo-store/GF/SF/fitting_rooms/booth", "5a47ddbb-004a-5158-9177-f8fbdcb24383"),
        ("demo-store/GF/BOH/stockroom", "bb36338b-6567-5b6a-9ab0-43c35a7cda11"),
        ("demo-store/GF/SF/Other", "72846910-2960-5159-8f4f-43c4b33a2a44"),
        ("demo-store/B1/BOH/receiving", "9f5b8155-0840-5cf1-82ed-214f1a6e834a"),
    ]

    @Test func stableKeyFormat() {
        let key = StableLocationID.stableKey(
            storeCode: "demo-store",
            floorCode: "GF",
            areaType: .sf,
            path: ["fitting_rooms", "booth"]
        )
        #expect(key == "demo-store/GF/SF/fitting_rooms/booth")
    }

    @Test func singleFloorOmitsFloorSegment() {
        let key = StableLocationID.stableKey(
            storeCode: "demo-single",
            floorCode: nil,
            areaType: .boh,
            path: ["stockroom"]
        )
        #expect(key == "demo-single/BOH/stockroom")
    }

    @Test func uuidIsDeterministic() {
        let key = "demo-store/GF/SF/checkout/self_checkout"
        let first = StableLocationID.uuid(forStableKey: key)
        let second = StableLocationID.uuid(forStableKey: key)
        #expect(first == second)
    }

    @Test func differentKeysDiffer() {
        let a = StableLocationID.uuid(forStableKey: "demo-store/GF/BOH/stockroom")
        let b = StableLocationID.uuid(forStableKey: "demo-store/B1/BOH/stockroom")
        #expect(a != b)
    }

    @Test func goldenVector() {
        for entry in Self.goldenVectors {
            let computed = StableLocationID.uuid(forStableKey: entry.key)
            #expect(computed.uuidString.lowercased() == entry.uuid.lowercased())
        }
    }

    @Test func componentsMatchRawKey() {
        let viaComponents = StableLocationID.uuid(
            storeCode: "demo-store", floorCode: "GF", areaType: .boh, path: ["stockroom"]
        )
        #expect(viaComponents.uuidString.lowercased() == "bb36338b-6567-5b6a-9ab0-43c35a7cda11")
    }

    @Test func uuidV5MatchesReferenceImplementation() {
        // RFC 4122 DNS namespace; value from Python's uuid.uuid5(uuid.NAMESPACE_DNS, "python.org").
        let dns = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
        let computed = StableLocationID.uuidV5(namespace: dns, name: "python.org")
        #expect(computed.uuidString.lowercased() == "886313e1-3b8a-5372-9b90-0c9aee199e5d")
    }
}

struct EnumDriftTests {
    @Test func identifyMethodMatchesPostgres() {
        #expect(Set(IdentifyMethod.allCases.map(\.rawValue)) == [
            "scan", "manual_code", "name_search", "unidentified",
        ])
    }

    @Test func foundBucketMatchesPostgres() {
        #expect(Set(FoundBucket.allCases.map(\.rawValue)) == [
            "now", "lt15m", "lt30m", "b30m_1h", "b1_2h", "b2h_plus", "custom",
        ])
    }

    @Test func tagStateMatchesPostgres() {
        #expect(Set(TagState.allCases.map(\.rawValue)) == [
            "intact", "torn_off", "cut", "damaged", "concealed",
        ])
    }

    @Test func reportStatusMatchesPostgres() {
        #expect(Set(ReportStatus.allCases.map(\.rawValue)) == [
            "submitted", "reviewed", "actioned",
        ])
    }

    @Test func areaTypeMatchesPostgres() {
        #expect(Set(AreaType.allCases.map(\.rawValue)) == ["SF", "BOH"])
    }
}
