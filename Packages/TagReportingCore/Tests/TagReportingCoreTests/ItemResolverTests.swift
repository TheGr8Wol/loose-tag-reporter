import Foundation
import Testing
@testable import TagReportingCore

/// Synthetic product reference data only.
struct ItemResolverTests {
    private let refs = MockProductRefs()
    private var resolver: ItemResolver { ItemResolver(refs: refs) }

    @Test func enrichedItemLooksUpName() async {
        let result = await resolver.resolve(
            itemCode: "2000101",
            colourCode: "30",
            sizeCode: "103"
        )
        #expect(result.itemCode == "2000101")
        #expect(result.itemName == "Demo Cotton Crew T-Shirt")
        #expect(result.size == "03") // article size field 103 → size code 03
        #expect(result.colour == "30")
        #expect(result.identifyMethod == .scan)
    }

    @Test func unknownItemFallsBackToLabel() async {
        let result = await resolver.resolve(
            itemCode: "2999999",
            colourCode: "30",
            sizeCode: "103"
        )
        #expect(result.itemCode == "2999999")
        #expect(result.itemName == "Unknown item")
    }

    @Test func unidentifiedEscapePreservesBarcode() {
        let result = resolver.unidentified(tagBarcode: "2012345678903")
        #expect(result.itemCode == nil)
        #expect(result.identifyMethod == .unidentified)
        #expect(result.tagBarcode == "2012345678903")
    }

    @Test func manualKeepsBarcodeAndMethod() async {
        let result = await resolver.resolveManual(
            itemCode: "2000101",
            colourCode: "30",
            sizeCode: "103",
            tagBarcode: "2012345678903"
        )
        #expect(result.identifyMethod == .manualCode)
        #expect(result.tagBarcode == "2012345678903")
        #expect(result.itemName == "Demo Cotton Crew T-Shirt")
    }
}

private struct MockProductRefs: ProductReferenceProviding {
    func product(itemCode: String) async -> ProductRef? {
        if itemCode == "2000101" {
            return ProductRef(itemCode: "2000101", name: "Demo Cotton Crew T-Shirt", category: "Tops/T-Shirts")
        }
        return nil
    }

    func colourName(code: String) async -> String? {
        code == "30" ? "BLACK" : nil
    }

    func size(articleField: String) async -> (code: String, label: String)? {
        if articleField == "103" { return ("03", "M") }
        return nil
    }
}
