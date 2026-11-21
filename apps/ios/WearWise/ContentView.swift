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
            VStack(alignment: .leading, spacing: 28) {
                header
                mainActions
                recentWardrobe
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("WearWise", systemImage: "circle.grid.cross")
                    .font(.headline)
                    .accessibilityLabel("WearWise 衣语")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEARWISE")
                .font(.caption.weight(.bold))
                .tracking(2.4)
                .foregroundStyle(.secondary)

            Text("看清已有衣物，\n穿得更有把握。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("照片保留真实颜色，界面只保留清楚的黑色、白色与灰色层级。")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                        ? "还没有衣物，先添加一件"
                        : "已有 \(garmentStore.garments.count) 件衣物",
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
                    detail: "场合与三套搭配将在下一分支接入",
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
                .font(.system(size: 25, weight: .semibold))
                .frame(width: 52, height: 52)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(detail)
                    .font(.subheadline)
                    .opacity(0.76)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.headline)
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

            Text("当前分支只完成图形首页和照片衣柜。下一分支接入场合输入、三套照片推荐和替换。")
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
