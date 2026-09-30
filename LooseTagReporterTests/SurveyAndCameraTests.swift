import Foundation
import Testing
import TagReportingCore
@testable import LooseTagReporter

struct SurveyAndCameraTests {
    @Test @MainActor
    func singleFloorAutoSkipsFloorStep() async throws {
        let locations = MockLocationRepo(multiFloor: false, floors: [
            StoreFloor(id: UUID(), storeID: UUID(), code: "GF", label: "Ground Floor", sortOrder: 0),
        ])
        let vm = LocationSurveyViewModel(
            storeID: locations.storeID,
            locations: locations,
            isMultiFloor: false
        )
        await vm.start()
        #expect(vm.step == .area)
    }

    @Test @MainActor
    func otherBucketEntersTextStep() async throws {
        let endpoint = LocationNode(
            id: UUID(),
            storeID: UUID(),
            areaType: .sf,
            code: "Other",
            label: "Other?",
            kind: .endpoint,
            isOtherBucket: true
        )
        let locations = MockLocationRepo(multiFloor: false, endpoints: [endpoint])
        let vm = LocationSurveyViewModel(
            storeID: locations.storeID,
            locations: locations,
            isMultiFloor: false
        )
        await vm.start()
        await vm.selectArea(.sf)
        await vm.selectEndpoint(endpoint)
        #expect(vm.step == .otherText)
        vm.commitOther("near lift")
        if case .done(let sel) = vm.step {
            #expect(sel.otherText == "near lift")
            #expect(sel.isOtherBucket)
        } else {
            Issue.record("Expected done selection")
        }
    }

    @Test @MainActor
    func deactivatedEndpointNotSelectable() async throws {
        let active1 = LocationNode(
            id: UUID(), storeID: UUID(), areaType: .sf, code: "zone_a", label: "Zone A", kind: .endpoint, active: true
        )
        let active2 = LocationNode(
            id: UUID(), storeID: UUID(), areaType: .sf, code: "zone_b", label: "Zone B", kind: .endpoint, active: true
        )
        let dead = LocationNode(
            id: UUID(), storeID: UUID(), areaType: .sf, code: "zone_x", label: "Zone X", kind: .endpoint, active: false
        )
        let locations = MockLocationRepo(multiFloor: false, endpoints: [active1, active2, dead])
        let vm = LocationSurveyViewModel(
            storeID: locations.storeID,
            locations: locations,
            isMultiFloor: false
        )
        await vm.start()
        await vm.selectArea(.sf)
        #expect(Set(vm.options.map(\.code)) == ["zone_a", "zone_b"])
        await vm.selectEndpoint(dead)
        #expect(vm.selectedEndpoint == nil)
        #expect(vm.step == .endpoint)
    }

    @Test func cameraDeniedRoutesManual() {
        #expect(CameraPermissionController.shouldUseManualPath(.denied))
        #expect(CameraPermissionController.shouldUseManualPath(.unsupported))
        #expect(!CameraPermissionController.shouldUseManualPath(.authorized))
    }

    @Test func mockRecognizerReturnsFragments() async {
        let mock = MockRecognizer(fragments: ["100-2000101", "-30-103"])
        let bits = await mock.recognize(in: Data())
        #expect(bits.count == 2)
        let parsed = ArticleNumberParser().parse(bits)
        #expect(parsed?.itemCode == "2000101")
    }
}

private final class MockLocationRepo: LocationRepository, @unchecked Sendable {
    let storeID = UUID()
    let multiFloor: Bool
    let floors: [StoreFloor]
    let endpoints: [LocationNode]

    init(multiFloor: Bool, floors: [StoreFloor] = [], endpoints: [LocationNode] = []) {
        self.multiFloor = multiFloor
        self.floors = floors
        self.endpoints = endpoints
    }

    func floors(for storeID: UUID) async throws -> [StoreFloor] { floors }
    func children(of parentID: UUID?) async throws -> [LocationNode] {
        if parentID == nil { return endpoints }
        return []
    }
    func node(id: UUID) async throws -> LocationNode? { endpoints.first { $0.id == id } }
    func isSeedReady() async -> Bool { true }
}
