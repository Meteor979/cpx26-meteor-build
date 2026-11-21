import SwiftUI

struct OutfitDetailView: View {
    @ObservedObject var viewModel: OccasionRecommendationViewModel
    @EnvironmentObject private var garmentStore: GarmentStore
    @EnvironmentObject private var planStore: SavedPlanStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let outfitID: String

    @State private var isSaved = false
    @State private var saveError: String?

    private var resolved: ResolvedOutfit? {
        viewModel.outfit(id: outfitID)
            ?? viewModel.selectedOutfitID.flatMap {
                viewModel.outfit(id: $0)
            }
    }

    private var columns: [GridItem] {
        dynamicTypeSize >= .xxxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            if let resolved {
                VStack(alignment: .leading, spacing: 24) {
                    header(resolved)
                    photoCollage(resolved)
                    explanation(resolved)
                    actions(resolved)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "方案不存在",
                    systemImage: "exclamationmark.circle",
                    description: Text("请返回三套搭配重新选择。")
                )
            }
        }
        .background(Color.wearWiseBackground)
        .navigationTitle("搭配详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert(
            "无法保存",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("知道了") {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "请稍后重试。")
        }
    }

    private func header(_ outfit: ResolvedOutfit) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(outfit.outfit.title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("\(viewModel.resolvedQuery) · \(viewModel.formality.label) · \(WeatherData.demo.summary)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(outfit.sourceLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func photoCollage(_ outfit: ResolvedOutfit) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(outfit.items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    if let garment = item.garment {
                        GarmentPhotoView(garment: garment)
                    } else {
                        GarmentPlaceholderView(
                            name: item.displayName,
                            systemImage: "photo.badge.exclamationmark"
                        )
                        .accessibilityLabel("\(item.displayName)，照片缺失")
                    }
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(item.slot?.label ?? "衣物记录无法映射")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func explanation(_ outfit: ResolvedOutfit) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            detailSection(title: "推荐理由", items: outfit.outfit.reasons)
            detailSection(title: "取舍", items: outfit.outfit.tradeoffs)
        }
    }

    private func detailSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .padding(.top, 7)
                        .accessibilityHidden(true)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func actions(_ outfit: ResolvedOutfit) -> some View {
        VStack(spacing: 12) {
            Menu {
                replacementMenuContent(for: outfit)
            } label: {
                Label("替换单品", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.wearWiseInk, lineWidth: 2)
                    }
            }
            .foregroundStyle(Color.wearWiseInk)
            .disabled(viewModel.isRevising)

            Button {
                do {
                    try planStore.save(viewModel.makeSavedPlan(from: outfit))
                    isSaved = true
                } catch {
                    saveError = error.localizedDescription
                }
            } label: {
                Label(
                    isSaved ? "已保存到最近方案" : "确认这套",
                    systemImage: isSaved ? "checkmark.circle.fill" : "checkmark.circle"
                )
            }
            .buttonStyle(WearWisePrimaryButtonStyle())
            .disabled(isSaved)

            Button {
                dismiss()
            } label: {
                Label("返回三套搭配", systemImage: "chevron.left")
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())

            if viewModel.isRevising {
                Label("正在替换", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private func replacementMenuContent(for outfit: ResolvedOutfit) -> some View {
        let replaceable = outfit.items.compactMap(\.garment)
        if replaceable.isEmpty {
            Text("没有可替换的衣物")
        } else {
            ForEach(replaceable) { current in
                let candidates = replacementCandidates(for: current)
                if !candidates.isEmpty {
                    Menu(current.name) {
                        ForEach(candidates) { candidate in
                            Button(candidate.name) {
                                Task {
                                    await viewModel.revise(
                                        outfitID: outfit.id,
                                        replacement: candidate,
                                        garments: garmentStore.garments
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func replacementCandidates(for current: Garment) -> [Garment] {
        let currentIDs = Set(
            resolved?.items.compactMap { $0.garment?.id.uuidString.lowercased() } ?? []
        )
        return garmentStore.garments.filter {
            $0.slot == current.slot
                && !currentIDs.contains($0.id.uuidString.lowercased())
        }
    }
}
