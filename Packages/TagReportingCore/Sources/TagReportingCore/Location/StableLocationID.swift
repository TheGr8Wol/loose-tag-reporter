import Foundation
import CryptoKit

/// Canonical UUIDv5 helper for location taxonomy nodes.
/// Namespace and key format are frozen — see `docs/ADR-001-architecture.md`.
public enum StableLocationID {
    /// Project-specific UUIDv5 namespace (frozen).
    public static let namespace = UUID(uuidString: "7c9e6679-7425-40de-944b-e07fc1f90ae7")!

    /// Builds the stable key string consumed by UUIDv5.
    ///
    /// Format: `{storeCode}/{floorCode}/{areaType}/{path...}`
    /// - `floorCode` is omitted (empty segment skipped) for single-floor stores.
    /// - `areaType` is the raw `AreaType` value (`SF` or `BOH`).
    /// - `path` is one or more node codes from root → endpoint, joined by `/`.
    public static func stableKey(
        storeCode: String,
        floorCode: String?,
        areaType: AreaType,
        path: [String]
    ) -> String {
        var segments = [storeCode]
        if let floorCode, !floorCode.isEmpty {
            segments.append(floorCode)
        }
        segments.append(areaType.rawValue)
        segments.append(contentsOf: path)
        return segments.joined(separator: "/")
    }

    /// Deterministic location id for a stable key.
    public static func uuid(forStableKey stableKey: String) -> UUID {
        uuidV5(namespace: namespace, name: stableKey)
    }

    /// Convenience when callers already know the key components.
    public static func uuid(
        storeCode: String,
        floorCode: String?,
        areaType: AreaType,
        path: [String]
    ) -> UUID {
        uuid(forStableKey: stableKey(storeCode: storeCode, floorCode: floorCode, areaType: areaType, path: path))
    }

    // MARK: - UUIDv5 (RFC 4122)

    /// Internal (not private) so tests can check it against reference implementations.
    static func uuidV5(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { (raw: UnsafeRawBufferPointer) in
            Data(raw)
        }
        let nameBytes = Data(name.utf8)
        var hashInput = Data()
        hashInput.append(namespaceBytes)
        hashInput.append(nameBytes)

        let digest = Insecure.SHA1.hash(data: hashInput)
        var bytes = Data(digest.prefix(16))

        // Version 5
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        // RFC 4122 variant
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let tuple: uuid_t = bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            (
                raw[0], raw[1], raw[2], raw[3],
                raw[4], raw[5], raw[6], raw[7],
                raw[8], raw[9], raw[10], raw[11],
                raw[12], raw[13], raw[14], raw[15]
            )
        }
        return UUID(uuid: tuple)
    }
}
