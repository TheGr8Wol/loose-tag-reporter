import SwiftUI
import TagReportingCore

/// Scan shell (live camera lands later). Tag State chips + manual / sample identity paths.
struct ScanStepView: View {
    @Bindable var coordinator: ReportingFlowCoordinator
    @Environment(AppContainer.self) private var container

    @State private var tagState: TagState = .intact
    @State private var resolution: TagIdentityResolution?
    @State private var showManual = false
    @State private var manualCode = ""
    @State private var isResolving = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                DSColor.scanChrome.ignoresSafeArea(edges: .bottom)

                VStack(spacing: DSSpacing.lg) {
                    Spacer(minLength: DSSpacing.xl)
                    scanReticle
                    if let resolution {
                        resolveCard(resolution)
                    } else {
                        Text("Point at a security tag")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    tagStateGrid
                    Spacer(minLength: DSSpacing.md)
                }
                .padding(.horizontal, DSSpacing.lg)
            }

            Button(AppCopy.cantScan) { showManual = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md)
                .background(DSColor.scanChrome)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                PrimaryButton(
                    title: "Continue",
                    enabled: resolution != nil
                ) {
                    guard let resolution else { return }
                    Task {
                        await coordinator.applyIdentity(resolution, tagState: tagState)
                    }
                }
            }
            .background(DSColor.scanChrome)
        }
        .sheet(isPresented: $showManual) {
            ManualIdentifySheet(
                code: $manualCode,
                onUseItem: { code in
                    Task { await resolveManual(code) }
                    showManual = false
                },
                onUnidentified: {
                    Task {
                        resolution = ItemResolver(refs: refs).unidentified(tagBarcode: nil)
                    }
                    showManual = false
                },
                onCancel: { showManual = false }
            )
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Sample tag") {
                    Task { await resolveSample() }
                }
                .disabled(isResolving)
            }
        }
    }

    private var refs: any ProductReferenceProviding {
        container.productRefs ?? EmptyProductRefs()
    }

    private var scanReticle: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.white.opacity(0.55), lineWidth: 2)
            .frame(width: 220, height: 140)
            .overlay {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityHidden(true)
    }

    private func resolveCard(_ resolution: TagIdentityResolution) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Tag read · resolved offline")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(resolution.itemName ?? "Unidentified tag")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: DSSpacing.md) {
                if let code = resolution.itemCode {
                    Text("Item \(code)").font(.caption.monospaced())
                }
                if !resolution.colour.isEmpty {
                    Text("Colour \(resolution.colour)").font(.caption.monospaced())
                }
                if !resolution.size.isEmpty {
                    Text("Size \(resolution.size)").font(.caption.monospaced())
                }
            }
            .foregroundStyle(Color.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.lg)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tagStateGrid: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Tag state · required")
                .font(.caption.weight(.bold))
                .foregroundStyle(DSColor.accent)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                ForEach(TagState.allCases, id: \.rawValue) { state in
                    Button {
                        tagState = state
                    } label: {
                        Text(FlowLabels.tagState(state))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(tagState == state ? DSColor.accent : Color.clear)
                            .overlay {
                                Rectangle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            }
                    }
                    .accessibilityAddTraits(tagState == state ? .isSelected : [])
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func resolveSample() async {
        isResolving = true
        defer { isResolving = false }
        resolution = await ItemResolver(refs: refs).resolve(
            itemCode: "2000101",
            colourCode: "30",
            sizeCode: "103",
            method: .scan
        )
    }

    private func resolveManual(_ code: String) async {
        isResolving = true
        defer { isResolving = false }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        resolution = await ItemResolver(refs: refs).resolveManual(itemCode: trimmed)
    }
}

private struct ManualIdentifySheet: View {
    @Binding var code: String
    var onUseItem: (String) -> Void
    var onUnidentified: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    Text("Tag damaged or won't scan. Enter it by hand — the report still counts.")
                        .font(.subheadline)
                        .foregroundStyle(DSColor.ink2)
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Item code")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DSColor.accent)
                        TextField("0000000", text: $code)
                            .keyboardType(.numberPad)
                            .font(.system(.title2, design: .monospaced).weight(.semibold))
                            .padding()
                            .background(DSColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Button(AppCopy.cantIdentify, action: onUnidentified)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSColor.ink2)
                }
                .padding(DSSpacing.xl)
            }
            .background(DSColor.bg)
            .navigationTitle("Identify tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Scan", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this item") {
                        onUseItem(code)
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EmptyProductRefs: ProductReferenceProviding {
    func product(itemCode: String) async -> ProductRef? { nil }
    func colourName(code: String) async -> String? { nil }
    func size(articleField: String) async -> (code: String, label: String)? { nil }
}
