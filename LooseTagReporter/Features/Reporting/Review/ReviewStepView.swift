import SwiftUI
import TagReportingCore

struct ReviewStepView: View {
    @Bindable var coordinator: ReportingFlowCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text(AppCopy.reviewTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(DSColor.ink)

                VStack(spacing: 0) {
                    metaRow("Location", locationSummary)
                    metaRow("Found", FlowLabels.formatWindow(
                        start: coordinator.draft.foundWindowStart,
                        end: coordinator.draft.foundWindowEnd,
                        isEstimate: coordinator.draft.foundAtIsEstimate
                    ))
                    metaRow(
                        "Photo",
                        coordinator.draft.photoLocalPath == nil ? "Skipped" : "1 attached"
                    )
                }
                .padding(.horizontal, DSSpacing.lg)
                .background(DSColor.bg)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DSColor.line, lineWidth: 1)
                }

                Text("Tags · \(coordinator.draft.tags.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSColor.accent)

                ForEach(Array(coordinator.draft.tags.enumerated()), id: \.element.id) { index, tag in
                    tagRow(index: index + 1, tag: tag)
                }

                if let error = coordinator.submitError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DSColor.accent)
                }
            }
            .padding(DSSpacing.xl)
        }
        .background(DSColor.bg)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                SyncStatusPill(text: "Offline — will queue & sync automatically")
                    .frame(maxWidth: .infinity)

                HStack(spacing: DSSpacing.md) {
                    SecondaryButton(title: "‹ Back") {
                        Task { await coordinator.goBack() }
                    }
                    PrimaryButton(
                        title: AppCopy.submitReport,
                        enabled: !coordinator.isSubmitting
                    ) {
                        Task { await coordinator.submit() }
                    }
                }
            }
        }
    }

    private var locationSummary: String {
        if let other = coordinator.draft.locationOtherText, !other.isEmpty {
            return "Other · \(other)"
        }
        if coordinator.draft.locationID != nil {
            return "Selected"
        }
        return "—"
    }

    private func metaRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(DSColor.ink2)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, DSSpacing.md)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DSColor.line).frame(height: 1)
        }
    }

    private func tagRow(index: Int, tag: TagDraft) -> some View {
        HStack(spacing: DSSpacing.md) {
            Text("\(index)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(DSColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.itemName ?? "Unidentified tag")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(1)
                Text(tagSubtitle(tag))
                    .font(.caption)
                    .foregroundStyle(DSColor.ink2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let state = tag.tagState {
                Text(FlowLabels.tagState(state))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DSColor.accent)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func tagSubtitle(_ tag: TagDraft) -> String {
        [tag.itemCode, tag.colour.isEmpty ? nil : tag.colour, tag.size.isEmpty ? nil : tag.size]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
