import Foundation

/// Maps found-time buckets → an incident review window (start/end) for loss-prevention follow-up.
public struct FoundTimeResolver: Sendable {
    public struct Window: Equatable, Sendable {
        public var start: Date
        public var end: Date
        public var isEstimate: Bool
    }

    public init() {}

    /// Provisional bounds — nested lookback from `now`. Loss prevention can tune these per store.
    public func resolve(bucket: FoundBucket, now: Date) -> FoundTime {
        let window: Window
        switch bucket {
        case .now:
            window = Window(start: now.addingTimeInterval(-5 * 60), end: now, isEstimate: false)
        case .lt15m:
            window = Window(start: now.addingTimeInterval(-15 * 60), end: now, isEstimate: true)
        case .lt30m:
            window = Window(start: now.addingTimeInterval(-30 * 60), end: now, isEstimate: true)
        case .b30m_1h:
            window = Window(start: now.addingTimeInterval(-60 * 60), end: now.addingTimeInterval(-30 * 60), isEstimate: true)
        case .b1_2h:
            window = Window(start: now.addingTimeInterval(-120 * 60), end: now.addingTimeInterval(-60 * 60), isEstimate: true)
        case .b2h_plus:
            window = Window(start: now.addingTimeInterval(-4 * 3600), end: now.addingTimeInterval(-120 * 60), isEstimate: true)
        case .custom:
            // Caller supplies custom window; placeholder until UI sets bounds.
            window = Window(start: now.addingTimeInterval(-60 * 60), end: now, isEstimate: true)
        }

        return FoundTime(
            bucket: bucket,
            resolvedAt: window.end,
            windowStart: window.start,
            windowEnd: window.end,
            isEstimate: window.isEstimate
        )
    }
}
