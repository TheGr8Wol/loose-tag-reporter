import SwiftUI
import TagReportingCore

/// Location survey UI — gated on `seedReady` (A1-L-004).
struct LocationStepView: View {
    @Bindable var coordinator: ReportingFlowCoordinator
    var seedReady: Bool
    var locations: (any LocationRepository)?
    var storeConfig: (any StoreConfigRepository)?

    @State private var survey: LocationSurveyViewModel?
    @State private var otherText = ""
    @State private var loadError: String?
    @State private var isMultiFloorStore = false
    @State private var didApply = false

    var body: some View {
        Group {
            if !seedReady {
                waitingState(AppCopy.locationWaiting)
            } else if let loadError {
                waitingState(loadError)
            } else if let survey {
                surveyContent(survey)
            } else {
                ProgressView(AppCopy.referenceLoading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DSColor.bg)
        .task(id: seedReady) {
            guard seedReady else { return }
            await bootstrap()
        }
    }

    @ViewBuilder
    private func surveyContent(_ survey: LocationSurveyViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(AppCopy.whereTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(DSColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if !survey.breadcrumb.isEmpty {
                    breadcrumbRow(survey.breadcrumb)
                }

                if let error = survey.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DSColor.accent)
                }

                switch survey.step {
                case .floor:
                    ForEach(survey.floors) { floor in
                        SurveyRow(title: floor.label) {
                            Task { await survey.selectFloor(floor) }
                        }
                    }
                case .area:
                    SurveyRow(title: AppCopy.salesFloor) {
                        Task { await survey.selectArea(.sf) }
                    }
                    SurveyRow(title: AppCopy.backOfHouse) {
                        Task { await survey.selectArea(.boh) }
                    }
                case .endpoint:
                    ForEach(survey.options) { node in
                        SurveyRow(
                            title: node.label,
                            subtitle: node.isOtherBucket ? "type it — saved as Other, added to notes" : nil
                        ) {
                            Task { await survey.selectEndpoint(node) }
                        }
                    }
                case .subLevel:
                    ForEach(survey.options) { node in
                        SurveyRow(title: node.label) {
                            Task { await survey.selectSubLevel(node) }
                        }
                    }
                case .otherText:
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Describe the location")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DSColor.accent)
                        TextField("e.g. behind mirror trim", text: $otherText)
                            .padding()
                            .background(DSColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        PrimaryButton(
                            title: "Confirm location",
                            enabled: !otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            survey.commitOther(otherText)
                        }
                    }
                case .done:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(DSSpacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                SecondaryButton(title: "‹ Back") {
                    Task { await handleBack(survey) }
                }
            }
        }
        .onChange(of: doneLocationID(survey)) { _, id in
            guard id != nil, !didApply else { return }
            guard case .done(let selection) = survey.step else { return }
            didApply = true
            Task { await coordinator.applyLocation(selection) }
        }
    }

    private func doneLocationID(_ survey: LocationSurveyViewModel) -> UUID? {
        if case .done(let selection) = survey.step {
            return selection.locationID
        }
        return nil
    }

    private func handleBack(_ survey: LocationSurveyViewModel) async {
        switch survey.step {
        case .floor:
            await coordinator.goBack()
        case .area where !isMultiFloorStore:
            await coordinator.goBack()
        default:
            await survey.goBack()
        }
    }

    private func breadcrumbRow(_ parts: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text("›").foregroundStyle(DSColor.ink3)
                }
                Text(part)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DSColor.ink2)
            }
        }
    }

    private func waitingState(_ message: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(DSColor.ink2)
                .multilineTextAlignment(.center)
            SecondaryButton(title: "‹ Back") {
                Task { await coordinator.goBack() }
            }
            .padding(.horizontal, DSSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DSSpacing.xl)
    }

    private func bootstrap() async {
        loadError = nil
        didApply = false
        guard let locations else {
            loadError = "Location data unavailable"
            return
        }
        // A1-L-004: refuse survey until location seed is ready.
        guard await locations.isSeedReady() else {
            loadError = AppCopy.locationWaiting
            return
        }
        guard let storeID = coordinator.draft.storeID else {
            loadError = "Store not bound"
            return
        }
        isMultiFloorStore = (try? await storeConfig?.storeProfile())?.isMultiFloor ?? false
        let vm = LocationSurveyViewModel(
            storeID: storeID,
            locations: locations,
            isMultiFloor: isMultiFloorStore
        )
        survey = vm
        await vm.start()
    }
}
