import SwiftUI
import TagReportingCore

/// Hosts `ReportingFlowCoordinator` and the mockup-aligned step surfaces.
struct ReportingFlowView: View {
    @Environment(AppContainer.self) private var container
    @Bindable var coordinator: ReportingFlowCoordinator
    var seedReady: Bool

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.step != .confirmation {
                FlowProgressBar(fraction: FlowLabels.progress(for: coordinator.step))
            }

            Group {
                switch coordinator.step {
                case .scan:
                    ScanStepView(coordinator: coordinator)
                case .when:
                    WhenFoundView(coordinator: coordinator)
                case .photo:
                    PhotoStepView(coordinator: coordinator)
                case .location:
                    LocationStepView(
                        coordinator: coordinator,
                        seedReady: seedReady,
                        locations: container.locationRepository,
                        storeConfig: container.storeConfigRepository
                    )
                case .review:
                    ReviewStepView(coordinator: coordinator)
                case .confirmation:
                    ConfirmationStepView(coordinator: coordinator) {
                        container.sessionStore.signOut()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DSColor.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(AppCopy.switchStaff, role: .destructive) {
                        Task { await coordinator.discard() }
                        container.sessionStore.signOut()
                    }
                    Button(AppCopy.endShift, role: .destructive) {
                        Task { await coordinator.discard() }
                        container.sessionStore.signOut()
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .accessibilityLabel(AppCopy.switchStaff)
                }
            }
        }
        .task {
            await coordinator.resumeFromAutosave()
        }
    }
}
