import Foundation
import Testing

struct BootstrapTests {
    @Test func fixturesLoad() throws {
        let bundle = Bundle(for: BundleToken.self)
        let tagsURL = bundle.url(forResource: "sample_tags", withExtension: "json")
            ?? bundle.url(forResource: "sample_tags", withExtension: "json", subdirectory: "Fixtures")
        let profileURL = bundle.url(forResource: "demo_store_profile", withExtension: "json")
            ?? bundle.url(forResource: "demo_store_profile", withExtension: "json", subdirectory: "Fixtures")
        #expect(tagsURL != nil)
        #expect(profileURL != nil)
        _ = try Data(contentsOf: #require(tagsURL))
        _ = try Data(contentsOf: #require(profileURL))
    }
}

private final class BundleToken {}
