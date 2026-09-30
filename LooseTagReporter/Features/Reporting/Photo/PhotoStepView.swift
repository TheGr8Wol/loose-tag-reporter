import SwiftUI

struct PhotoStepView: View {
    @Bindable var coordinator: ReportingFlowCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("Exact spot")
                    .font(.title2.bold())
                    .foregroundStyle(DSColor.ink)

                Text("Optional, but a photo of exactly where the tag was makes the follow-up review much faster.")
                    .font(.subheadline)
                    .foregroundStyle(DSColor.ink2)

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.17, green: 0.15, blue: 0.15), Color(red: 0.08, green: 0.07, blue: 0.06)],
                                center: .topLeading,
                                startRadius: 20,
                                endRadius: 280
                            )
                        )
                        .frame(minHeight: 180)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text("Photo attach stub · camera lands with M3")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(DSSpacing.lg)
                }

                HStack(alignment: .top, spacing: DSSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(DSColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppCopy.photoNudge)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DSColor.ink)
                        Text("Faces and personal data are out of scope.")
                            .font(.footnote)
                            .foregroundStyle(DSColor.ink2)
                    }
                }
                .padding(DSSpacing.md)
                .background(DSColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(DSSpacing.xl)
        }
        .background(DSColor.bg)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button(AppCopy.skipPhoto) {
                    Task { await coordinator.skipPhoto() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: DSMetrics.minTapTarget)

                HStack(spacing: DSSpacing.md) {
                    SecondaryButton(title: "‹ Back") {
                        Task { await coordinator.goBack() }
                    }
                    PrimaryButton(title: AppCopy.takePhoto) {
                        // Stub attach path — real capture lands with M3/T11.
                        Task {
                            await coordinator.attachPhoto(localPath: "stub/photo.jpg")
                        }
                    }
                }
            }
        }
    }
}
