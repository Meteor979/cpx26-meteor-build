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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                mainActions
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
                OccasionFoundationView()
            } label: {
                HomeActionCard(
                    title: "今天穿什么？",
                    detail: "即将开放",
                    systemImage: "wand.and.stars"
                )
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())
            .accessibilityHint("查看搭配功能的当前状态")
        }
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

private struct OccasionFoundationView: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "tshirt.circle")
                .font(.system(size: 64, weight: .medium))
                .accessibilityHidden(true)

            Text("场合与推荐")
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Text("将在下一分支开放。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wearWiseBackground)
    }
}
