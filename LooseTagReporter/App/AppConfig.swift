import Foundation
import TagReportingCore

/// Runtime configuration loaded from xcconfig / Info.plist / managed app config.
struct AppConfig: Sendable {
    var supabaseURL: URL?
    var supabaseAnonKey: String?
    var bundleVersion: String
    var buildNumber: String

    /// Dev-default store binding — non-production only.
    var devDefaultStoreID: UUID?
    var devDefaultStoreCode: String?

    static let current: AppConfig = {
        let info = Bundle.main.infoDictionary ?? [:]
        let urlString = info["SUPABASE_URL"] as? String
        return AppConfig(
            supabaseURL: urlString.flatMap(URL.init(string:)),
            supabaseAnonKey: info["SUPABASE_ANON_KEY"] as? String,
            bundleVersion: info["CFBundleShortVersionString"] as? String ?? "0.1.0",
            buildNumber: info["CFBundleVersion"] as? String ?? "1",
            devDefaultStoreID: UUID(uuidString: "a0000000-0000-4000-8000-000000000001"),
            devDefaultStoreCode: "demo-store"
        )
    }()
}

struct FeatureFlags: Sendable {
    var telemetryEnabled: Bool
    var scannerPreWarmEnabled: Bool

    static let releaseDefaults = FeatureFlags(telemetryEnabled: true, scannerPreWarmEnabled: true)
}

/// MDM-managed app configuration keys (see WS-E D4).
struct ManagedAppConfig: Sendable {
    var storeID: UUID?
    var storeCode: String?
    var staffCodeLength: Int?
    var telemetryEnabled: Bool?

    static func load(from userDefaults: UserDefaults = .standard) -> ManagedAppConfig {
        let dict = userDefaults.dictionary(forKey: "com.apple.configuration.managed") ?? [:]
        let storeIDString = dict["store_id"] as? String
        return ManagedAppConfig(
            storeID: storeIDString.flatMap(UUID.init(uuidString:)),
            storeCode: dict["store_code"] as? String,
            staffCodeLength: dict["staff_code_length"] as? Int,
            telemetryEnabled: dict["telemetry_enabled"] as? Bool
        )
    }

    var isStoreBound: Bool { storeID != nil }
}

struct StoreBinding: Sendable {
    let storeID: UUID
    let storeCode: String
    let isProductionBinding: Bool

    static func resolve(appConfig: AppConfig = .current, managed: ManagedAppConfig = .load()) -> StoreBinding? {
        if let storeID = managed.storeID, let storeCode = managed.storeCode {
            return StoreBinding(storeID: storeID, storeCode: storeCode, isProductionBinding: true)
        }
        if let storeID = appConfig.devDefaultStoreID, let storeCode = appConfig.devDefaultStoreCode {
            return StoreBinding(storeID: storeID, storeCode: storeCode, isProductionBinding: false)
        }
        return nil
    }
}
