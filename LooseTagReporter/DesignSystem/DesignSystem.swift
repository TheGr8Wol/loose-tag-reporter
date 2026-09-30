import SwiftUI
import UIKit

enum DSColor {
    static let bg = Color(light: "FFFFFF", dark: "0F1115")
    static let surface = Color(light: "F7F8FA", dark: "171A21")
    static let surface2 = Color(light: "EEF0F4", dark: "1F232C")
    static let ink = Color(light: "14171F", dark: "F3F5F8")
    static let ink2 = Color(light: "5B6270", dark: "A9B0BD")
    static let ink3 = Color(light: "878E9B", dark: "7C8391")
    static let line = Color(light: "E3E6EB", dark: "2A2F3A")
    /// Neutral demo accent (white text on it meets WCAG AA for large text in both modes).
    static let accent = Color(light: "1F5FD6", dark: "3B78EB")
    static let accentPress = Color(light: "174BAD", dark: "2F66D1")
    static let accentTint = Color(light: "E8F0FC", dark: "16223A")
    static let scanChrome = Color(light: "0B0C0F", dark: "0B0C0F")
}

enum DSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DSMetrics {
    static let primaryMinHeight: CGFloat = 56
    static let minTapTarget: CGFloat = 44
}

private extension Color {
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(hex: hex) ?? .label
        })
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v >> 16) & 0xff) / 255,
            green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255,
            alpha: 1
        )
    }
}

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(enabled ? Color.white : DSColor.ink3)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DSMetrics.primaryMinHeight)
                .background(enabled ? DSColor.accent : DSColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DSMetrics.primaryMinHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DSColor.ink, lineWidth: 1)
                )
        }
        .accessibilityLabel(title)
    }
}

struct BigChip: View {
    let title: String
    var selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(selected ? Color.white : DSColor.ink)
                .padding(.horizontal, DSSpacing.lg)
                .frame(minHeight: DSMetrics.primaryMinHeight)
                .background(selected ? DSColor.accent : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? DSColor.accent : DSColor.ink, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }
}

struct NumericCodeField: View {
    @Binding var text: String
    var placeholder: String = "Staff code"

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .font(.system(.title, design: .monospaced).weight(.semibold))
            .multilineTextAlignment(.center)
            .padding()
            .background(DSColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(placeholder)
            .onChange(of: text) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered.count > StaffCodePolicy.maxLength {
                    text = String(filtered.prefix(StaffCodePolicy.maxLength))
                } else if filtered != newValue {
                    text = filtered
                }
            }
    }
}

enum AppCopy {
    static let staffCodePrompt = "Enter your employee ID"
    static let staffContinue = "Start reporting"
    static let scannerPlaceholder = "Scanner"
    static let referenceReady = "Reference data ready"
    static let referenceLoading = "Loading reference data…"
    static let cantIdentify = "Can't identify this tag"
    static let cantScan = "Can't scan this tag?"
    static let wrongItem = "Wrong item? Re-enter code"
    static let photoNudge = "Photograph the spot, not people"
    static let skipPhoto = "Skip photo"
    static let takePhoto = "Take photo"
    static let whenTitle = "When was\nit found?"
    static let whereTitle = "Where was\nit found?"
    static let reviewTitle = "Review report"
    static let submitReport = "Submit report"
    static let queued = "Queued · will sync when you're back online"
    static let logged = "Logged — thanks."
    static let fittingRoom = "Fitting Room (FR)"
    static let backOfHouse = "Back of House (BOH)"
    static let salesFloor = "Sales Floor (SF)"
    static let switchStaff = "Switch staff"
    static let endShift = "End shift"
    static let locationWaiting = "Waiting for store locations…"
}

/// Bottom CTA strip pinned via `.safeAreaInset(edge: .bottom)` — clears home indicator.
struct BottomActionBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            content()
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [DSColor.bg.opacity(0), DSColor.bg],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct SurveyRow: View {
    let title: String
    var subtitle: String? = nil
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DSColor.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(DSColor.ink2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark" : "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? DSColor.accent : DSColor.ink3)
            }
            .padding(.horizontal, DSSpacing.lg)
            .frame(minHeight: DSMetrics.minTapTarget + 12)
            .background(selected ? DSColor.accentTint : DSColor.bg)
            .overlay(alignment: .bottom) {
                Rectangle().fill(DSColor.line).frame(height: 1)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }
}

struct SyncStatusPill: View {
    let text: String

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Circle()
                .fill(DSColor.ink3)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DSColor.ink2)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColor.surface2)
        .clipShape(Capsule())
    }
}

struct FlowProgressBar: View {
    let fraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(DSColor.line)
                Rectangle()
                    .fill(DSColor.accent)
                    .frame(width: max(0, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
