import Foundation
import TagReportingCore

/// Decision-tap budget for the happy path (Now + Submit). Tag State / Photo skip are free.
enum FlowTapMetrics {
    static let maxDecisionTapsHappyPath = 2

    static func decisionTaps(
        choseNow: Bool,
        skippedPhoto: Bool,
        selectedTagStateOnScan: Bool
    ) -> Int {
        var taps = 1 // Submit always
        if choseNow { taps += 1 } // Now
        // Tag state chip on scan + photo skip do not count as decision taps
        _ = skippedPhoto
        _ = selectedTagStateOnScan
        return taps
    }

    static func withinBudget(_ taps: Int) -> Bool {
        taps <= maxDecisionTapsHappyPath
    }
}

enum ReportingStep: String, Codable, Sendable, Equatable {
    case scan
    case when
    case photo
    case location
    case review
    case confirmation
}

@MainActor
@Observable
final class ReportingFlowCoordinator {
    private let clock: any NowProviding
    private let reportRepository: GRDBReportRepository
    private let itemResolver: ItemResolver
    private let foundTimeResolver = FoundTimeResolver()
    private let storeBinding: StoreBinding?
    private let session: SessionStore
    private let canSubmit: Bool

    private(set) var draft: ReportDraft
    private(set) var step: ReportingStep = .scan
    private(set) var path: [ReportingStep] = []
    private(set) var lastSubmitOutcome: SubmitOutcome?
    private(set) var submitError: String?
    private(set) var isSubmitting = false

    init(
        clock: any NowProviding,
        reportRepository: GRDBReportRepository,
        itemResolver: ItemResolver,
        storeBinding: StoreBinding?,
        session: SessionStore,
        canSubmit: Bool
    ) {
        self.clock = clock
        self.reportRepository = reportRepository
        self.itemResolver = itemResolver
        self.storeBinding = storeBinding
        self.session = session
        self.canSubmit = canSubmit
        var draft = ReportDraft(step: ReportingStep.scan.rawValue)
        draft.reporterEmpID = session.currentReporter?.empID
        draft.storeID = storeBinding?.storeID
        self.draft = draft
    }

    func resumeFromAutosave() async {
        if let saved = try? await reportRepository.loadDraft() {
            draft = saved
            step = ReportingStep(rawValue: saved.step) ?? .scan
        }
    }

    // MARK: - Scan

    func applyIdentity(_ resolution: TagIdentityResolution, tagState: TagState) async {
        var tag = TagDraft(
            tagBarcode: resolution.tagBarcode,
            itemCode: resolution.itemCode,
            size: resolution.size,
            colour: resolution.colour,
            identifyMethod: resolution.identifyMethod,
            tagState: tagState,
            itemName: resolution.itemName
        )
        if draft.tags.isEmpty {
            draft.tags = [tag]
        } else {
            draft.tags[draft.tags.count - 1] = tag
        }
        await commitStep(.when)
    }

    func markUnidentified(tagBarcode: String?) async {
        let resolution = itemResolver.unidentified(tagBarcode: tagBarcode)
        await applyIdentity(resolution, tagState: .intact)
    }

    // MARK: - When

    func chooseNow() async {
        let now = clock.now
        let found = foundTimeResolver.resolve(bucket: .now, now: now)
        draft.foundBucket = .now
        draft.foundAt = found.resolvedAt
        draft.foundWindowStart = found.windowStart
        draft.foundWindowEnd = found.windowEnd
        draft.foundAtIsEstimate = found.isEstimate
        await commitStep(.photo)
    }

    func chooseEarlier(bucket: FoundBucket) async {
        let found = foundTimeResolver.resolve(bucket: bucket, now: clock.now)
        draft.foundBucket = bucket
        draft.foundAt = found.resolvedAt
        draft.foundWindowStart = found.windowStart
        draft.foundWindowEnd = found.windowEnd
        draft.foundAtIsEstimate = found.isEstimate
        await commitStep(.photo)
    }

    // MARK: - Photo

    func skipPhoto() async {
        draft.photoLocalPath = nil
        // Location survey itself is gated on seedReady (A1-L-004) in LocationStepView.
        await commitStep(.location)
    }

    func attachPhoto(localPath: String) async {
        draft.photoLocalPath = localPath
        await commitStep(.location)
    }

    // MARK: - Location

    /// Apply a survey selection. Caller must only invoke after seedReady / `LocationRepository.isSeedReady()`.
    func applyLocation(_ selection: LocationSelection) async {
        draft.locationID = selection.locationID
        draft.locationOtherText = selection.otherText
        if let other = selection.otherText, !other.isEmpty {
            // Idempotent notes mirror
            let marker = "[Other location] \(other)"
            if draft.notes?.contains(marker) != true {
                draft.notes = [draft.notes, marker].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            }
        }
        await commitStep(.review)
    }

    // MARK: - Review / Submit

    func submit() async {
        guard !isSubmitting else { return }
        submitError = nil

        guard canSubmit else {
            submitError = "Store not bound — submit disabled"
            return
        }
        guard let storeID = draft.storeID ?? storeBinding?.storeID,
              let locationID = draft.locationID,
              let bucket = draft.foundBucket,
              let foundAt = draft.foundAt,
              let reporter = draft.reporterEmpID ?? session.currentReporter?.empID,
              !draft.tags.isEmpty,
              draft.tags.allSatisfy({ $0.tagState != nil })
        else {
            submitError = "Report incomplete"
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let clientUUID = draft.clientUUID ?? UUID()
        let foundTime = FoundTime(
            bucket: bucket,
            resolvedAt: foundAt,
            windowStart: draft.foundWindowStart,
            windowEnd: draft.foundWindowEnd,
            isEstimate: draft.foundAtIsEstimate ?? true
        )

        var photos: [ReportPhoto] = []
        if let path = draft.photoLocalPath {
            photos = [ReportPhoto(localPath: path, capturedAt: clock.now)]
        }

        let report = Report(
            clientUUID: clientUUID,
            storeID: storeID,
            locationID: locationID,
            locationOtherText: draft.locationOtherText,
            foundTime: foundTime,
            notes: draft.notes,
            tags: draft.tags.map {
                Tag(
                    id: $0.id,
                    tagBarcode: $0.tagBarcode,
                    itemCode: $0.itemCode,
                    size: $0.size,
                    colour: $0.colour,
                    identifyMethod: $0.identifyMethod,
                    tagState: $0.tagState ?? .intact,
                    itemName: $0.itemName
                )
            },
            photos: photos,
            deviceID: deviceID(),
            reporterEmpID: reporter,
            createdAt: clock.now
        )

        do {
            try await reportRepository.saveReport(report)
            try await reportRepository.clearDraft()
            lastSubmitOutcome = .queued
            step = .confirmation
            path = []
        } catch {
            submitError = error.localizedDescription
            // Never claim Logged; stay on review
        }
    }

    func startNewReport() {
        draft = ReportDraft(
            reporterEmpID: session.currentReporter?.empID,
            storeID: storeBinding?.storeID,
            step: ReportingStep.scan.rawValue
        )
        lastSubmitOutcome = nil
        submitError = nil
        step = .scan
        path = []
    }

    func discard() async {
        if let client = draft.clientUUID {
            // Photo dirs cleaned via orphan sweep / explicit delete when PhotoFileStore wired
            _ = client
        }
        try? await reportRepository.clearDraft()
        startNewReport()
    }

    // MARK: - Navigation

    func goBack() async {
        guard step != .confirmation else { return }
        guard let previous = path.popLast() else { return }
        step = previous
        draft.step = previous.rawValue
        try? await reportRepository.saveDraft(draft)
    }

    private func commitStep(_ next: ReportingStep) async {
        path.append(step)
        step = next
        draft.step = next.rawValue
        try? await reportRepository.saveDraft(draft)
    }

    private func deviceID() -> String {
        // Stable-enough POC device id; replace with identifierForVendor when needed.
        "poc-device"
    }
}

enum SubmitOutcome: Equatable, Sendable {
    case queued
    case synced
}
