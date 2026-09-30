import Foundation
import Observation
import TagReportingCore

/// Read-only location survey engine (T16). Consumes `LocationRepository`; never re-seeds.
@MainActor
@Observable
final class LocationSurveyViewModel {
    enum Step: Equatable {
        case floor
        case area
        case endpoint
        case subLevel
        case otherText
        case done(LocationSelection)
    }

    private let storeID: UUID
    private let locations: any LocationRepository
    private let isMultiFloor: Bool

    private(set) var step: Step = .floor
    private(set) var floors: [StoreFloor] = []
    private(set) var options: [LocationNode] = []
    private(set) var breadcrumb: [String] = []
    private(set) var selectedFloor: StoreFloor?
    private(set) var selectedArea: AreaType?
    private(set) var selectedEndpoint: LocationNode?
    private(set) var otherText: String = ""
    private(set) var errorMessage: String?

    init(storeID: UUID, locations: any LocationRepository, isMultiFloor: Bool) {
        self.storeID = storeID
        self.locations = locations
        self.isMultiFloor = isMultiFloor
    }

    func start() async {
        errorMessage = nil
        if isMultiFloor {
            do {
                floors = try await locations.floors(for: storeID)
                if floors.count == 1 {
                    await selectFloor(floors[0])
                } else {
                    step = .floor
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            selectedFloor = nil
            step = .area
        }
    }

    func selectFloor(_ floor: StoreFloor) async {
        selectedFloor = floor
        breadcrumb = [floor.label]
        selectedArea = nil
        selectedEndpoint = nil
        step = .area
    }

    func selectArea(_ area: AreaType) async {
        selectedArea = area
        breadcrumb = breadcrumb.filter { $0 == selectedFloor?.label }
        breadcrumb.append(area == .sf ? "Sales Floor (SF)" : "Back of House (BOH)")
        await loadEndpoints()
    }

    func selectEndpoint(_ node: LocationNode) async {
        guard node.active else { return }
        selectedEndpoint = node
        breadcrumb.append(node.label)

        if node.isOtherBucket {
            step = .otherText
            return
        }

        do {
            let children = try await locations.children(of: node.id)
            let activeChildren = children.filter(\.active)
            if activeChildren.isEmpty {
                finish(node: node, other: nil)
            } else if activeChildren.count == 1 {
                // Auto-advance single-option sub-level
                await selectSubLevel(activeChildren[0])
            } else {
                options = activeChildren
                step = .subLevel
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSubLevel(_ node: LocationNode) async {
        guard node.active else { return }
        breadcrumb.append(node.label)
        finish(node: node, other: nil)
    }

    func commitOther(_ text: String) {
        guard let endpoint = selectedEndpoint else { return }
        otherText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        finish(node: endpoint, other: otherText.isEmpty ? nil : otherText)
    }

    func goBack() async {
        switch step {
        case .subLevel:
            breadcrumb = Array(breadcrumb.dropLast())
            await loadEndpoints()
        case .otherText, .endpoint:
            selectedEndpoint = nil
            otherText = ""
            breadcrumb = Array(breadcrumb.prefix(2))
            step = .area
        case .area:
            if isMultiFloor {
                breadcrumb = []
                selectedArea = nil
                step = .floor
            }
        default:
            break
        }
    }

    private func loadEndpoints() async {
        guard let area = selectedArea else { return }
        do {
            let all = try await locations.children(of: nil)
            let floorID = selectedFloor?.id
            options = all.filter { node in
                node.active
                    && node.areaType == area
                    && node.parentID == nil
                    && (floorID == nil || node.floorID == floorID)
            }
            // Auto-advance single endpoint
            if options.count == 1 {
                await selectEndpoint(options[0])
            } else {
                step = .endpoint
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish(node: LocationNode, other: String?) {
        let selection = LocationSelection(
            locationID: node.id,
            breadcrumb: breadcrumb,
            otherText: other,
            isOtherBucket: node.isOtherBucket
        )
        step = .done(selection)
    }
}
