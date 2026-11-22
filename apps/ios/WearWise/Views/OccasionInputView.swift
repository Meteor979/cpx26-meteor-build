import SwiftUI

struct OccasionInputView: View {
    @EnvironmentObject private var garmentStore: GarmentStore
    @EnvironmentObject private var weatherStore: WeatherContextStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel = OccasionRecommendationViewModel()
    @FocusState private var queryFocused: Bool

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
        .navigationTitle("场合")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await viewModel.loadPresets()
        }
        .onAppear {
            viewModel.updateWeatherContext(weatherStore.context)
        }
        .onChange(of: weatherStore.context) { _, context in
            viewModel.updateWeatherContext(context)
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.queryDidChange()
        }
        .navigationDestination(isPresented: $viewModel.showsRecommendations) {
            RecommendationResultsView(viewModel: viewModel)
                .environmentObject(garmentStore)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今晚去哪里？")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1.1)
                .accessibilityAddTraits(.isHeader)

            Text("说出场合，我们会用衣柜照片生成搭配。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var queryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "例如：第一次去女朋友家吃饭",
                text: $viewModel.query,
                axis: .vertical
            )
            .lineLimit(1...3)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($queryFocused)
            .onSubmit {
                Task { await viewModel.resolveOccasion() }
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
            .accessibilityLabel("自由输入场合")

            if
                viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Label("输入场合后可解析", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用场合")
                .font(.headline)

            LazyVGrid(columns: presetColumns, spacing: 10) {
                ForEach(viewModel.presets.prefix(4)) { preset in
                    Button {
                        viewModel.usePreset(preset)
                        queryFocused = true
                    } label: {
                        Label(preset.name, systemImage: "tag")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(WearWiseSecondaryButtonStyle())
                    .accessibilityHint("填入场合输入框")
                }
            }
        }
    }

    private var resolveButton: some View {
        Button {
            queryFocused = false
            Task { await viewModel.resolveOccasion() }
        } label: {
            if viewModel.isResolving {
                HStack {
                    ProgressView()
                        .tint(Color(uiColor: .systemBackground))
                    Text("正在理解")
                }
            } else {
                Label("解析场合", systemImage: "sparkles")
            }
        }
        .buttonStyle(WearWisePrimaryButtonStyle())
        .disabled(!viewModel.canResolve)
        .accessibilityHint(
            viewModel.canResolve ? "解析输入并确认正式程度" : "请先输入场合"
        )
    }

    private var resolutionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("理解为")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                    "调整正式程度：\(viewModel.formality.label)",
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
                Task {
                    await viewModel.generateRecommendations(
                        garments: garmentStore.garments
                    )
                }
            } label: {
                if viewModel.isGenerating {
                    HStack {
                        ProgressView()
                            .tint(Color(uiColor: .systemBackground))
                        Text("正在生成")
                    }
                } else {
                    Label("生成三套搭配", systemImage: "square.grid.2x2")
                }
            }
            .buttonStyle(WearWisePrimaryButtonStyle())
            .disabled(viewModel.isGenerating)
        }
        .wearWiseCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "理解为\(viewModel.formality.label)，适合\(viewModel.resolvedQuery)，重点\(viewModel.resolutionHighlights)"
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
                Button("重试") {
                    Task { await viewModel.resolveOccasion() }
                }
                .buttonStyle(WearWiseSecondaryButtonStyle())
            }
        }
        .wearWiseCard()
    }
}
