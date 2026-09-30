import Foundation

// MARK: - Postgres-aligned enums (raw values must match DDL 1:1)

public enum AreaType: String, Codable, Sendable, CaseIterable {
    case sf = "SF"
    case boh = "BOH"
}

public enum FoundBucket: String, Codable, Sendable, CaseIterable {
    case now
    case lt15m
    case lt30m
    case b30m_1h = "b30m_1h"
    case b1_2h = "b1_2h"
    case b2h_plus = "b2h_plus"
    case custom
}

public enum TagState: String, Codable, Sendable, CaseIterable {
    case intact
    case tornOff = "torn_off"
    case cut
    case damaged
    case concealed
}

public enum IdentifyMethod: String, Codable, Sendable, CaseIterable {
    case scan
    case manualCode = "manual_code"
    case nameSearch = "name_search"
    case unidentified
}

public enum ReportStatus: String, Codable, Sendable, CaseIterable {
    case submitted
    case reviewed
    case actioned
}

public enum SyncState: String, Codable, Sendable, CaseIterable {
    case pending
    case syncing
    case synced
    case failed
}

public enum SurveyNodeKind: String, Codable, Sendable, CaseIterable {
    case floor
    case area
    case endpoint
    case subLevel = "sub_level"
}

public enum EndSessionReason: String, Codable, Sendable, CaseIterable {
    case idleTimeout = "idle_timeout"
    case explicitLogout = "explicit_logout"
    case reauthDiscard = "reauth_discard"
}

public enum TradingPhase: String, Codable, Sendable, CaseIterable {
    case preOpen = "pre_open"
    case trading
    case postClose = "post_close"
}

public enum FlagThresholdScope: String, Codable, Sendable, CaseIterable {
    case global
    case area
    case floor
    case endpoint
}

public enum FlagReason: String, Codable, Sendable, CaseIterable {
    case bohAnyTime = "boh_any_time"
    case sfTrading = "sf_trading"
    case sfPreOpenThreshold = "sf_pre_open_threshold"
    case sfPostCloseThreshold = "sf_post_close_threshold"
    case concealedAndDamaged = "concealed_and_damaged"
}
