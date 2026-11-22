import SwiftUI

struct RecommendationResultsView: View {
    @ObservedObject var viewModel: OccasionRecommendationViewModel
    @EnvironmentObject private var garmentStore: GarmentStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        dynamicTypeSize >= .xxxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let warning = viewModel.recommendationWarning {
                    Label(warning, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .wearWiseCard()
                }

                ForEach(viewModel.recommendations) { outfit in
                    outfitCard(outfit)
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .navigationTitle("Three outfits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.resolvedQuery)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.contextSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if viewModel.recommendations.count < 3 {
                Text(countExplanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func outfitCard(_ resolved: ResolvedOutfit) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Outfit \(outfitCode(resolved.id))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(resolved.outfit.title)
                        .font(.title3.weight(.bold))
                }
                Spacer()
            }

            Text(viewModel.resolutionHighlights)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(resolved.items) { item in
                    ResolvedOutfitItemView(item: item)
                }
            }

            if let firstReason = resolved.outfit.reasons.first {
                Text(firstReason)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(resolved.sourceLabel, systemImage: "checkmark.seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            NavigationLink {
                OutfitDetailView(
                    viewModel: viewModel,
                    outfitID: resolved.id
                )
                .environmentObject(garmentStore)
                .onAppear {
                    viewModel.selectOutfit(id: resolved.id)
                }
            } label: {
                Label("View details", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())
        }
        .padding(16)
        .background(
            Color.wearWiseSurface,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    Color.wearWiseInk,
                    lineWidth: viewModel.selectedOutfitID == resolved.id ? 3 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.selectedOutfitID == resolved.id {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Color.wearWiseInk, in: Capsule())
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(10)
            }
        }
    }

    private var countExplanation: String {
        switch viewModel.resultCountReason {
        case "limited_candidates":
            "The wardrobe has limited combinations. Only valid options are shown."
        case "fallback_degraded":
            "The backend is unavailable. Local fallback outfits are shown."
        default:
            "Fewer than three outfits are available."
        }
    }

    private func outfitCode(_ id: String) -> String {
        guard let index = viewModel.recommendations.firstIndex(where: { $0.id == id }) else {
            return "A"
        }
        return ["A", "B", "C"][min(index, 2)]
    }
}

private struct ResolvedOutfitItemView: View {
    let item: ResolvedOutfitItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let garment = item.garment {
                GarmentPhotoView(garment: garment)
            } else {
                GarmentPlaceholderView(
                    name: item.displayName,
                    systemImage: "photo.badge.exclamationmark"
                )
                .accessibilityLabel(
                    "\(item.displayName), photo or wardrobe record unavailable"
                )
            }

            Text(item.displayName)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let warning = item.mappingWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
