import Foundation
import TagReportingCore

enum FlowLabels {
    static func tagState(_ state: TagState) -> String {
        switch state {
        case .intact: return "Intact"
        case .tornOff: return "Torn off"
        case .concealed: return "Concealed"
        case .cut: return "Cut"
        case .damaged: return "Damaged"
        }
    }

    static func foundBucket(_ bucket: FoundBucket) -> String {
        switch bucket {
        case .now: return "Now"
        case .lt15m: return "Under 15 min ago"
        case .lt30m: return "Under 30 min ago"
        case .b30m_1h: return "30 min – 1 hr ago"
        case .b1_2h: return "1 – 2 hrs ago"
        case .b2h_plus: return "2+ hrs ago"
        case .custom: return "Custom…"
        }
    }

    static func progress(for step: ReportingStep) -> CGFloat {
        switch step {
        case .scan: return 0.2
        case .when: return 0.4
        case .photo: return 0.6
        case .location: return 0.8
        case .review, .confirmation: return 1.0
        }
    }

    static func formatWindow(start: Date?, end: Date?, isEstimate: Bool?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let start, let end else { return "—" }
        let range = "\(formatter.string(from: start))–\(formatter.string(from: end))"
        return (isEstimate == true) ? "\(range) · est." : range
    }
}
