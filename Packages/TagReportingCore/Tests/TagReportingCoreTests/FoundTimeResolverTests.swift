import Foundation
import Testing
@testable import TagReportingCore

struct FoundTimeResolverTests {
    let resolver = FoundTimeResolver()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func nowBucketNotEstimate() {
        let ft = resolver.resolve(bucket: .now, now: now)
        #expect(ft.isEstimate == false)
        #expect(ft.bucket == .now)
        #expect(ft.windowEnd == now)
    }

    @Test func lt15mWindow() {
        let ft = resolver.resolve(bucket: .lt15m, now: now)
        #expect(ft.isEstimate)
        #expect(ft.windowStart == now.addingTimeInterval(-15 * 60))
        #expect(ft.windowEnd == now)
    }

    @Test func b30m1hDisjointWindow() {
        let ft = resolver.resolve(bucket: .b30m_1h, now: now)
        #expect(ft.windowStart == now.addingTimeInterval(-60 * 60))
        #expect(ft.windowEnd == now.addingTimeInterval(-30 * 60))
    }

    @Test func bucketRoundTrip() {
        for bucket in FoundBucket.allCases {
            let ft = resolver.resolve(bucket: bucket, now: now)
            #expect(ft.bucket == bucket)
            #expect(ft.windowStart != nil)
            #expect(ft.windowEnd != nil)
        }
    }
}
