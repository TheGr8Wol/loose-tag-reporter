import SwiftUI
import TagReportingCore

struct RootRouter: View {
    @Environment(AppContainer.self) private var container
    @StateObject private var launchSequence: LaunchSequence
    @State private var backgroundedAt: Date?
    @State private var flowCoordinator: ReportingFlowCoordinator?

    init(container: AppContainer) {
        _launchSequence = StateObject(wrappedValue: LaunchSequence(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if container.sessionStore.isAuthenticated {
                    scannerSurface
                } else {
                    StaffCodeEntryView(session: container.sessionStore) {}
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.bg)
            .safeAreaInset(edge: .top, spacing: 0) {
                if container.requiresDevBindingBanner {
                    DevBindingBanner(
                        hasDevBinding: container.storeBinding != nil,
                        isProductionBinding: container.storeBinding?.isProductionBinding == true
                    )
                }
            }
        }
        .task {
            await launchSequence.start()
        }
        .onChange(of: container.sessionStore.isAuthenticated) { _, authenticated in
            if authenticated {
                ensureCoordinator()
            } else {
                flowCoordinator = nil
            }
        }
        .onAppear {
            if container.sessionStore.isAuthenticated {
                ensureCoordinator()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            backgroundedAt = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            _ = container.sessionStore.applyIdlePolicy(backgroundedAt: backgroundedAt)
            backgroundedAt = nil
            Task {
                await container.syncEngine?.triggerSyncIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var scannerSurface: some View {
        switch launchSequence.phase {
        case .booting:
            ProgressView("Starting…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .seeding, .scannerReady, .seedReady:
            if let flowCoordinator {
                ReportingFlowView(
                    coordinator: flowCoordinator,
                    seedReady: launchSequence.seedReady
                )
            } else {
                ProgressView("Preparing report flow…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { ensureCoordinator() }
            }
        case .seedFailed(let message):
            SeedFailureView(message: message)
        }
    }

    private func ensureCoordinator() {
        guard flowCoordinator == nil else { return }
        guard let reportRepository = container.reportRepository else { return }
        let refs: any ProductReferenceProviding = container.productRefs ?? EmptyProductRefs()
        flowCoordinator = ReportingFlowCoordinator(
            clock: container.clock,
            reportRepository: reportRepository,
            itemResolver: ItemResolver(refs: refs),
            storeBinding: container.storeBinding,
            session: container.sessionStore,
            canSubmit: container.canSubmitReports
        )
    }
}

/// A1-L-005 / B4-L-001: distinct DEV vs unbound copy; top safe-area inset from RootRouter.
private struct DevBindingBanner: View {
    let hasDevBinding: Bool
    let isProductionBinding: Bool

    var body: some View {
        let showDev = hasDevBinding && !isProductionBinding
        Text(showDev
             ? "DEV STORE BINDING — not for production"
             : "NO STORE BINDING — submit disabled")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, 8)
            .background(showDev ? Color.orange : Color.red)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SeedFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Text("Could not load store data")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(DSColor.ink2)
        }
        .padding()
    }
}

#Preview {
    let container = PreviewContainer.make()
    return RootRouter(container: container)
        .environment(container)
}
