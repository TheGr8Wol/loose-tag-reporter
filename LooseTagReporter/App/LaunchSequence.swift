import Foundation

@MainActor
final class LaunchSequence: ObservableObject {
    enum Phase: Equatable {
        case booting
        case scannerReady
        case seeding
        case seedReady
        case seedFailed(String)
    }

    @Published private(set) var phase: Phase = .booting
    @Published private(set) var seedReady: Bool = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Cold-start contract (ADR-001 §3): scanner live immediately; seeding async off the critical path.
    func start() async {
        phase = .scannerReady
        wireReachabilitySyncTrigger()
        await container.reachability.startMonitoring()

        phase = .seeding
        await runReferenceSeed()
        await sweepOrphans()
    }

    private func wireReachabilitySyncTrigger() {
        guard let reachability = container.reachability as? Reachability else { return }
        reachability.onStatusChange = { [weak self] status in
            guard status == .online else { return }
            Task { @MainActor in
                await self?.container.syncEngine?.triggerSyncIfNeeded()
            }
        }
    }

    private func runReferenceSeed() async {
        guard let seed = container.seedService else {
            if let err = container.persistenceError {
                phase = .seedFailed(err)
            } else {
                // Preview / no-DB mode
                seedReady = true
                phase = .seedReady
            }
            return
        }

        do {
            _ = try await seed.ensureSeeded()
            try await container.productRefRepository?.warmIndex()
            try await container.productRefs?.warm()
            seedReady = try await seed.isSeedReady()
            phase = seedReady ? .seedReady : .seedFailed("Seed incomplete")
            if seedReady {
                await container.syncEngine?.triggerSyncIfNeeded()
            }
        } catch {
            phase = .seedFailed(error.localizedDescription)
        }
    }

    private func sweepOrphans() async {
        try? await container.reportRepository?.sweepOrphanPhotos()
    }
}
