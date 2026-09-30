import Foundation

enum CSVSeedParser {
    static func rows(from csv: String) -> [[String: String]] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return [] }
        let headers = parseLine(headerLine)
        return lines.dropFirst().compactMap { line in
            let cols = parseLine(line)
            guard cols.count == headers.count else { return nil }
            var dict: [String: String] = [:]
            for (h, c) in zip(headers, cols) {
                dict[h] = c
            }
            return dict
        }
    }

    /// Minimal RFC-4180-ish split (handles quoted fields).
    private static func parseLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
                i = next
                continue
            }
            if ch == ",", !inQuotes {
                result.append(current)
                current = ""
                i = line.index(after: i)
                continue
            }
            current.append(ch)
            i = line.index(after: i)
        }
        result.append(current)
        return result
    }
}
