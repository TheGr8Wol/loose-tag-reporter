import SwiftUI
import TagReportingCore

struct WhenFoundView: View {
    @Bindable var coordinator: ReportingFlowCoordinator

    private let earlierBuckets: [FoundBucket] = [
        .lt15m, .lt30m, .b30m_1h, .b1_2h, .b2h_plus
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(AppCopy.whenTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(DSColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await coordinator.chooseNow() }
                } label: {
                    Text("Now")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 78)
                        .background(DSColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel("Now")

                Text("Earlier")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSColor.accent)

                VStack(spacing: DSSpacing.sm) {
                    ForEach(earlierBuckets, id: \.rawValue) { bucket in
                        Button {
                            Task { await coordinator.chooseEarlier(bucket: bucket) }
                        } label: {
                            Text(FlowLabels.foundBucket(bucket))
                                .font(.headline)
                                .foregroundStyle(DSColor.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DSSpacing.lg)
                                .frame(minHeight: DSMetrics.primaryMinHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(DSColor.ink, lineWidth: 1)
                                )
                        }
                        .accessibilityLabel(FlowLabels.foundBucket(bucket))
                    }
                }
            }
            .padding(DSSpacing.xl)
        }
        .background(DSColor.bg)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                SecondaryButton(title: "‹ Back") {
                    Task { await coordinator.goBack() }
                }
            }
        }
    }
}
