import Foundation

/// Describes a printed product article number: fixed-width numeric segments separated by
/// hyphens, with the item, colour and size fields at known positions.
///
/// Retailers print these on price tags in many layouts, so the layout is data, not code.
public struct ArticleNumberFormat: Equatable, Sendable {
    /// Width of each numeric segment, left to right.
    public var segmentLengths: [Int]
    /// Index into `segmentLengths` for each identity field.
    public var itemIndex: Int
    public var colourIndex: Int
    public var sizeIndex: Int

    public init(segmentLengths: [Int], itemIndex: Int, colourIndex: Int, sizeIndex: Int) {
        precondition(!segmentLengths.isEmpty, "Article number needs at least one segment")
        precondition(
            [itemIndex, colourIndex, sizeIndex].allSatisfy { segmentLengths.indices.contains($0) },
            "Field index out of range"
        )
        self.segmentLengths = segmentLengths
        self.itemIndex = itemIndex
        self.colourIndex = colourIndex
        self.sizeIndex = sizeIndex
    }

    /// Synthetic demo layout `PPP-IIIIIII-CC-SSS` (prefix, 7-digit item, colour, size; 15 digits).
    public static let demo = ArticleNumberFormat(
        segmentLengths: [3, 7, 2, 3],
        itemIndex: 1,
        colourIndex: 2,
        sizeIndex: 3
    )

    /// Total digit count when the number is printed without separators.
    public var totalDigits: Int { segmentLengths.reduce(0, +) }
}

/// Parses a printed product article number from OCR text into item / colour / size codes.
///
/// Robust to the usual OCR failure modes: line wraps, letter/digit confusion (O/0, I/1, S/5,
/// B/8, Z/2), missing separators and unicode dashes. Rejects bare retail barcodes and
/// letter-prefixed internal codes so they can never auto-submit as an article number.
public struct ArticleNumberParser: Sendable {
    public struct Result: Equatable, Sendable {
        public var itemCode: String
        public var colourCode: String
        public var sizeCode: String
        public var confidence: Double
        public var normalized: String

        public init(
            itemCode: String,
            colourCode: String,
            sizeCode: String,
            confidence: Double,
            normalized: String
        ) {
            self.itemCode = itemCode
            self.colourCode = colourCode
            self.sizeCode = sizeCode
            self.confidence = confidence
            self.normalized = normalized
        }
    }

    /// Minimum confidence to auto-advance (high confidence).
    public static let highConfidenceThreshold: Double = 0.85

    public let format: ArticleNumberFormat

    public init(format: ArticleNumberFormat = .demo) {
        self.format = format
    }

    /// Parses one or more OCR fragments (line wraps are concatenated).
    public func parse(_ fragments: [String]) -> Result? {
        let joined = fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "")
        return parse(joined)
    }

    public func parse(_ raw: String) -> Result? {
        let cleaned = normalize(raw)
        guard !cleaned.isEmpty else { return nil }

        // Reject known non-article patterns early.
        if Self.isRejectedPattern(cleaned) { return nil }

        // Strict segment layout with an optional parenthetical trailer.
        let body = format.segmentLengths.map { "(\\d{\($0)})" }.joined(separator: "-")
        let pattern = "^" + body + #"(?:\([^)]*\))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        guard let match = regex.firstMatch(in: cleaned, range: range),
              match.numberOfRanges == format.segmentLengths.count + 1,
              let itemRange = Range(match.range(at: format.itemIndex + 1), in: cleaned),
              let colourRange = Range(match.range(at: format.colourIndex + 1), in: cleaned),
              let sizeRange = Range(match.range(at: format.sizeIndex + 1), in: cleaned)
        else {
            return nil
        }

        var confidence = 1.0
        // Soft penalty if the original had digit-confusion substitutions.
        if Self.hadDigitConfusion(raw) {
            confidence = 0.9
        }
        // Soft penalty if we had to insert missing separators into a dense digit run.
        if !raw.contains("-") && cleaned.contains("-") {
            confidence = min(confidence, 0.88)
        }

        return Result(
            itemCode: String(cleaned[itemRange]),
            colourCode: String(cleaned[colourRange]),
            sizeCode: String(cleaned[sizeRange]),
            confidence: confidence,
            normalized: cleaned
        )
    }

    // MARK: - Normalization

    public func normalize(_ raw: String) -> String {
        var s = raw.uppercased()
        s = s.replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "\n", with: "")
        s = s.replacingOccurrences(of: "\r", with: "")
        s = s.replacingOccurrences(of: "—", with: "-")
        s = s.replacingOccurrences(of: "–", with: "-")
        s = s.replacingOccurrences(of: "_", with: "-")

        // Digit-confusion in alphanumeric OCR noise → digits for numeric segments.
        s = Self.confuseDigits(s)

        // A dense digit run of the full article length gets its separators re-inserted.
        if !s.contains("-") {
            let digits = s.filter(\.isNumber)
            if digits.count >= format.totalDigits {
                var remaining = Substring(digits.prefix(format.totalDigits))
                var segments: [String] = []
                for length in format.segmentLengths {
                    segments.append(String(remaining.prefix(length)))
                    remaining = remaining.dropFirst(length)
                }
                var shaped = segments.joined(separator: "-")
                // Preserve a trailing parenthetical if present on the original.
                if let paren = raw.range(of: #"\([^)]*\)"#, options: .regularExpression) {
                    shaped += String(raw[paren])
                }
                return shaped
            }
        }

        return s
    }

    private static func confuseDigits(_ s: String) -> String {
        // Applied globally in article-number context — letters elsewhere fail the digit regex.
        s
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "Z", with: "2")
    }

    private static func hadDigitConfusion(_ raw: String) -> Bool {
        let upper = raw.uppercased()
        return upper.contains("O") || upper.contains("I") || upper.contains("S")
            || upper.contains("B") || upper.contains("Z")
    }

    private static func isRejectedPattern(_ cleaned: String) -> Bool {
        // Bare EAN-13 / EAN-8 / UPC-A barcodes (digits only, no separators).
        let digitsOnly = cleaned.filter(\.isNumber)
        if cleaned == String(digitsOnly) {
            let n = digitsOnly.count
            if n == 8 || n == 12 || n == 13 {
                return true
            }
            // Dense full-length runs are handled by separator insertion — not rejected here.
        }

        // Letter-prefixed internal codes (department / style / class) must never auto-submit.
        if cleaned.range(of: #"^[A-Z]{2}\d+"#, options: .regularExpression) != nil,
           !cleaned.contains("-") {
            return true
        }
        return false
    }
}
