import SwiftUI

enum OccasionUICopy {
    static let parse = "Parse occasion"
    static let generate = "Generate three outfits"
    static let tryAgain = "Try again"
    static let useLocalRules = "Use local rules"
    static let contextChanged = "Context changed. Generate again."
}

struct OccasionInputView: View {
    @EnvironmentObject private var garmentStore: GarmentStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = OccasionRecommendationViewModel()
    @FocusState private var queryFocused: Bool
    @State private var operationTask: Task<Void, Never>?

    private var presetColumns: [GridItem] {
        dynamicTypeSize >= .xxxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                queryField
                presetsSection
                resolveButton

                if viewModel.profile != nil {
                    resolutionCard
                }

                if let errorMessage = viewModel.errorMessage {
                    errorCard(errorMessage)
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .navigationTitle("Occasion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await viewModel.loadPresets()
        }
        .onChange(of: viewModel.query) { _, _ in
            operationTask?.cancel()
            operationTask = nil
            viewModel.cancelOperations()
            viewModel.queryDidChange()
        }
        .onDisappear {
            operationTask?.cancel()
            operationTask = nil
            viewModel.cancelOperations()
        }
        .navigationDestination(isPresented: $viewModel.showsRecommendations) {
            RecommendationResultsView(viewModel: viewModel)
                .environmentObject(garmentStore)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where are you going?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1.1)
                .accessibilityAddTraits(.isHeader)

            Text("Describe the occasion in Chinese or English.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var queryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "e.g. dinner with my partner's family",
                text: $viewModel.query,
                axis: .vertical
            )
            .lineLimit(1...3)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($queryFocused)
            .onSubmit {
                startResolve()
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(
                Color.wearWiseSurface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.wearWiseBorder, lineWidth: 1)
            }
            .accessibilityLabel("Occasion description")

            if
                viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Label("Enter an occasion to continue", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common occasions")
                .font(.headline)

            LazyVGrid(columns: presetColumns, spacing: 10) {
                ForEach(viewModel.presets.prefix(4)) { preset in
                    Button {
                        operationTask?.cancel()
                        operationTask = nil
                        viewModel.cancelOperations()
                        viewModel.usePreset(preset)
                        queryFocused = true
                    } label: {
                        Label(preset.name, systemImage: "tag")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(WearWiseSecondaryButtonStyle())
                    .accessibilityHint("Fill in the occasion field")
                }
            }
        }
    }

    private var resolveButton: some View {
        Button {
            queryFocused = false
            startResolve()
        } label: {
            if viewModel.isResolving {
                HStack {
                    ProgressView()
                        .tint(Color(uiColor: .systemBackground))
                    Text(
                        viewModel.operationMessage.isEmpty
                            ? "Resolving your occasion..."
                            : viewModel.operationMessage
                    )
                }
            } else {
                Label(OccasionUICopy.parse, systemImage: "sparkles")
            }
        }
        .buttonStyle(WearWisePrimaryButtonStyle())
        .disabled(!viewModel.canResolve)
        .accessibilityHint(
            viewModel.canResolve
                ? "Resolve the occasion and confirm formality"
                : "Enter an occasion first"
        )
    }

    private var resolutionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Understood as")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.resolvedProfileName)
                        .font(.headline)
                    Text(viewModel.formality.label)
                        .font(.title2.weight(.bold))
                }
                Spacer()
                Text(viewModel.resolutionSource)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Label(viewModel.resolvedQuery, systemImage: "calendar")
                .font(.body.weight(.semibold))

            Label(viewModel.resolutionHighlights, systemImage: "sparkles")
                .font(.body)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(FormalityBand.allCases) { band in
                    Button {
                        viewModel.adjustFormality(band)
                    } label: {
                        if band == viewModel.formality {
                            Label(band.label, systemImage: "checkmark")
                        } else {
                            Text(band.label)
                        }
                    }
                }
            } label: {
                Label(
                    "Adjust formality: \(viewModel.formality.label)",
                    systemImage: "slider.horizontal.3"
                )
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, 14)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.wearWiseInk, lineWidth: 1.5)
                }
            }
            .foregroundStyle(Color.wearWiseInk)

            Button {
                startGenerate()
            } label: {
                if viewModel.isGenerating {
                    HStack {
                        ProgressView()
                            .tint(Color(uiColor: .systemBackground))
                        Text(
                            viewModel.operationMessage.isEmpty
                                ? "Building three outfit options..."
                                : viewModel.operationMessage
                        )
                    }
                } else {
                    Label(OccasionUICopy.generate, systemImage: "square.grid.2x2")
                }
            }
            .buttonStyle(WearWisePrimaryButtonStyle())
            .disabled(viewModel.isGenerating)

            if viewModel.contextChanged {
                Label(
                    OccasionUICopy.contextChanged,
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .wearWiseCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Understood as \(viewModel.formality.label), for \(viewModel.resolvedQuery), focus \(viewModel.resolutionHighlights)"
        )
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.body)
                Button(OccasionUICopy.tryAgain) {
                    if viewModel.recommendationTimedOut {
                        startGenerate()
                    } else {
                        startResolve()
                    }
                }
                .buttonStyle(WearWiseSecondaryButtonStyle())

                if viewModel.recommendationTimedOut {
                    Button(OccasionUICopy.useLocalRules) {
                        viewModel.useLocalRecommendations(
                            garments: garmentStore.garments
                        )
                    }
                    .buttonStyle(WearWiseSecondaryButtonStyle())
                }
            }
        }
        .wearWiseCard()
    }

    private func startResolve() {
        guard !viewModel.isResolving else {
            return
        }
        operationTask?.cancel()
        operationTask = Task {
            await viewModel.resolveOccasion()
        }
    }

    private func startGenerate() {
        guard !viewModel.isGenerating else {
            return
        }
        operationTask?.cancel()
        operationTask = Task {
            await viewModel.generateRecommendations(
                garments: garmentStore.garments
            )
        }
    }
}
