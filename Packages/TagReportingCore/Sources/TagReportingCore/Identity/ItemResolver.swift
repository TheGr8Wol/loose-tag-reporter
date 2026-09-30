import Foundation

/// Enrichment lookups for scan → identity resolution (backed by the on-device reference seed).
public protocol ProductReferenceProviding: Sendable {
    func product(itemCode: String) async -> ProductRef?
    func colourName(code: String) async -> String?
    /// Maps the article-number size field (e.g. `103`) → size code (`03`) + label (`M`).
    func size(articleField: String) async -> (code: String, label: String)?
}

public struct ItemResolver: Sendable {
    private let refs: any ProductReferenceProviding

    public init(refs: any ProductReferenceProviding) {
        self.refs = refs
    }

    /// Resolve from a successful article-number parse (+ optional barcode).
    public func resolve(
        itemCode: String,
        colourCode: String,
        sizeCode: String,
        tagBarcode: String? = nil,
        method: IdentifyMethod = .scan,
        confidence: Double? = nil
    ) async -> TagIdentityResolution {
        let product = await refs.product(itemCode: itemCode)
        _ = await refs.colourName(code: colourCode)
        let size = await refs.size(articleField: sizeCode)

        return TagIdentityResolution(
            itemCode: itemCode,
            size: size?.code ?? sizeCode,
            colour: colourCode,
            identifyMethod: method,
            tagBarcode: tagBarcode,
            itemName: product?.name ?? "Unknown item",
            itemCategory: product?.category,
            confidence: confidence
        )
    }

    /// Manual re-entry of an item code (Wrong item? path). Preserves barcode.
    public func resolveManual(
        itemCode: String,
        colourCode: String = "",
        sizeCode: String = "",
        tagBarcode: String? = nil
    ) async -> TagIdentityResolution {
        await resolve(
            itemCode: itemCode,
            colourCode: colourCode,
            sizeCode: sizeCode,
            tagBarcode: tagBarcode,
            method: .manualCode,
            confidence: 1.0
        )
    }

    /// Name-search selection.
    public func resolveFromProduct(
        _ product: ProductRef,
        colourCode: String,
        sizeCode: String,
        tagBarcode: String? = nil
    ) async -> TagIdentityResolution {
        await resolve(
            itemCode: product.itemCode,
            colourCode: colourCode,
            sizeCode: sizeCode,
            tagBarcode: tagBarcode,
            method: .nameSearch,
            confidence: 1.0
        )
    }

    /// Escape hatch — find is never blocked.
    public func unidentified(tagBarcode: String? = nil) -> TagIdentityResolution {
        TagIdentityResolution(
            itemCode: nil,
            size: "",
            colour: "",
            identifyMethod: .unidentified,
            tagBarcode: tagBarcode,
            itemName: nil,
            itemCategory: nil,
            confidence: 0
        )
    }
}
