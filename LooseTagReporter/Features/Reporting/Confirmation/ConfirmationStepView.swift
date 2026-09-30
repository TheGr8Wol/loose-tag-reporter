import SwiftUI

struct ConfirmationStepView: View {
    @Bindable var coordinator: ReportingFlowCoordinator
    var onDoneForNow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DSSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(DSColor.accent)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(AppCopy.logged)
                    .font(.title.bold())
                    .foregroundStyle(DSColor.ink)

                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(DSColor.ink2)
                    .multilineTextAlignment(.center)

                SyncStatusPill(text: AppCopy.queued)
            }
            .padding(.horizontal, DSSpacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.bg)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                PrimaryButton(title: "Start new report") {
                    coordinator.startNewReport()
                }
                SecondaryButton(title: "Done for now", action: onDoneForNow)
            }
        }
    }

    private var summaryLine: String {
        let count = coordinator.draft.tags.count
        let tagWord = count == 1 ? "tag" : "tags"
        return "\(count) \(tagWord). That helps loss prevention find the pattern."
    }
}
