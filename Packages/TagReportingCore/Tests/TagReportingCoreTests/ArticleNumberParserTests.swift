import Foundation
import Testing
@testable import TagReportingCore

/// All fixtures are synthetic and use the demo layout `PPP-IIIIIII-CC-SSS`.
struct ArticleNumberParserTests {
    let parser = ArticleNumberParser()

    @Test func canonicalTag() {
        let result = parser.parse("100-2000101-30-103(12-34)")
        #expect(result?.itemCode == "2000101")
        #expect(result?.colourCode == "30")
        #expect(result?.sizeCode == "103")
        #expect((result?.confidence ?? 0) >= ArticleNumberParser.highConfidenceThreshold)
    }

    @Test func lineWrapFragmentsConcatenate() {
        let result = parser.parse(["100-20001", "01-30-103"])
        #expect(result?.itemCode == "2000101")
        #expect(result?.colourCode == "30")
        #expect(result?.sizeCode == "103")
    }

    @Test func digitConfusionO0I1S5() {
        // O→0 in the colour and size segments
        let result = parser.parse("100-2000101-3O-1O3")
        #expect(result?.itemCode == "2000101")
        #expect(result?.colourCode == "30")
        #expect(result?.sizeCode == "103")
        #expect(result?.confidence == 0.9)
    }

    @Test func denseDigitsWithoutSeparators() {
        let result = parser.parse("100200010130103")
        #expect(result?.itemCode == "2000101")
        #expect(result?.colourCode == "30")
        #expect(result?.sizeCode == "103")
        #expect((result?.confidence ?? 1) < 1.0)
    }

    @Test func unicodeDashesAndSpacesNormalise() {
        let result = parser.parse("100 – 2000101 — 30 - 103")
        #expect(result?.itemCode == "2000101")
    }

    @Test func rejectsWrongSegmentCount() {
        #expect(parser.parse("100-2000101-30") == nil)
    }

    @Test func rejectsLetterPrefixedInternalCode() {
        #expect(parser.parse("QX107") == nil)
    }

    @Test func rejectsStyleCode() {
        #expect(parser.parse("AC00270NX-XY") == nil)
    }

    @Test func rejectsBareEAN() {
        #expect(parser.parse("2012345678903") == nil)
        #expect(parser.parse("12345670") == nil)
    }

    @Test func rejectsEmpty() {
        #expect(parser.parse("") == nil)
        #expect(parser.parse("   ") == nil)
    }

    @Test func customFormatSupportsOtherLayouts() {
        // Item-first layout: IIIII-CCC-SS
        let format = ArticleNumberFormat(segmentLengths: [5, 3, 2], itemIndex: 0, colourIndex: 1, sizeIndex: 2)
        let custom = ArticleNumberParser(format: format)
        let result = custom.parse("12345-070-42")
        #expect(result?.itemCode == "12345")
        #expect(result?.colourCode == "070")
        #expect(result?.sizeCode == "42")
        // The demo layout must not accept it.
        #expect(parser.parse("12345-070-42") == nil)
    }
}
