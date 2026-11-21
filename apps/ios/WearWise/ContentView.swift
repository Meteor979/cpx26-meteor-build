import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(.wearWiseInk)
    }
}

private struct HomeView: View {
    @EnvironmentObject private var garmentStore: GarmentStore
    @EnvironmentObject private var planStore: SavedPlanStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                mainActions
                recentPlan
                recentWardrobe
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("WearWise", systemImage: "circle.grid.cross")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("WearWise 衣语")

            Text("穿得更有把握。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var mainActions: some View {
        VStack(spacing: 14) {
            NavigationLink {
                WardrobeView()
            } label: {
                HomeActionCard(
                    title: "我的衣柜",
                    detail: garmentStore.garments.isEmpty
                        ? "添加第一件衣物"
                        : "\(garmentStore.garments.count) 件衣物",
                    systemImage: "cabinet.fill"
                )
            }
            .buttonStyle(WearWisePrimaryButtonStyle())
            .accessibilityHint("打开照片衣柜")

            NavigationLink {
                OccasionInputView()
            } label: {
                HomeActionCard(
                    title: "今天穿什么？",
                    detail: "输入场合，生成搭配",
                    systemImage: "wand.and.stars"
                )
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())
            .accessibilityHint("输入场合并生成搭配")
        }
    }

    @ViewBuilder
    private var recentPlan: some View {
        if let plan = planStore.latest {
            VStack(alignment: .leading, spacing: 12) {
                Text("最近方案")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                NavigationLink {
                    SavedPlanDetailView(plan: plan)
                        .environmentObject(garmentStore)
                } label: {
                    HStack(spacing: 14) {
                        planPreview(plan)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(plan.outfitTitle)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(plan.occasion)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(plan.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .wearWiseCard()
                }
                .buttonStyle(.plain)
                .accessibilityHint("重新查看已保存方案")
            }
        }
    }

    private func planPreview(_ plan: SavedPlan) -> some View {
        let garmentsByID = Dictionary(
            uniqueKeysWithValues: garmentStore.garments.map {
                ($0.id.uuidString.lowercased(), $0)
            }
        )
        return HStack(spacing: 3) {
            let previewCount = dynamicTypeSize >= .xxxLarge ? 1 : 3
            ForEach(Array(plan.itemIDs.prefix(previewCount).enumerated()), id: \.offset) { _, id in
                if let garment = garmentsByID[id.lowercased()] {
                    GarmentPhotoView(garment: garment)
                        .frame(width: 58)
                } else {
                    GarmentPlaceholderView(
                        name: "无法映射",
                        systemImage: "photo.badge.exclamationmark"
                    )
                    .frame(width: 58)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var recentWardrobe: some View {
        if !garmentStore.garments.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("最近添加")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(garmentStore.garments.prefix(4)) { garment in
                            VStack(alignment: .leading, spacing: 8) {
                                GarmentPhotoView(garment: garment, thumbnail: true)
                                    .frame(width: 128)

                                Text(garment.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .frame(width: 128, alignment: .leading)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

private struct HomeActionCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .opacity(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SavedPlanDetailView: View {
    @EnvironmentObject private var garmentStore: GarmentStore
    let plan: SavedPlan

    private var items: [ResolvedOutfitItem] {
        let garmentsByID = Dictionary(
            uniqueKeysWithValues: garmentStore.garments.map {
                ($0.id.uuidString.lowercased(), $0)
            }
        )
        return plan.itemIDs.map {
            ResolvedOutfitItem(remoteID: $0, garment: garmentsByID[$0.lowercased()])
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.outfitTitle)
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("\(plan.occasion) · \(plan.formality.label) · \(plan.weather.summary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(items) { item in
                        HStack(spacing: 14) {
                            if let garment = item.garment {
                                GarmentPhotoView(garment: garment)
                                    .frame(width: 78)
                            } else {
                                GarmentPlaceholderView(
                                    name: item.displayName,
                                    systemImage: "photo.badge.exclamationmark"
                                )
                                .frame(width: 78)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.displayName)
                                    .font(.headline)
                                Text(item.slot?.label ?? "衣物记录无法映射")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Label(plan.recommendationSource, systemImage: "checkmark.seal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .navigationTitle("已保存方案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
