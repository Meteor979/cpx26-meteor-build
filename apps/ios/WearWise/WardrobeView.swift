import SwiftUI

struct WardrobeView: View {
    @EnvironmentObject private var garmentStore: GarmentStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeSheet: WardrobeSheet?

    private var columns: [GridItem] {
        if dynamicTypeSize >= .xxxLarge {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Button {
                    activeSheet = .add
                } label: {
                    Label("添加衣物", systemImage: "camera.fill")
                }
                .buttonStyle(WearWisePrimaryButtonStyle())
                .accessibilityHint("拍摄衣物或从相册选择")

                if garmentStore.garments.isEmpty {
                    emptyState
                } else {
                    wardrobeGroups
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wearWiseBackground)
        .navigationTitle("我的衣柜")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                AddGarmentView()
                    .environmentObject(garmentStore)
            case let .edit(garment):
                AddGarmentView(editingGarment: garment)
                    .environmentObject(garmentStore)
            }
        }
        .alert(
            "衣柜出现问题",
            isPresented: Binding(
                get: { garmentStore.errorMessage != nil },
                set: { if !$0 { garmentStore.clearError() } }
            )
        ) {
            Button("知道了") {
                garmentStore.clearError()
            }
        } message: {
            Text(garmentStore.errorMessage ?? "请稍后重试。")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("照片衣柜")
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Text("\(garmentStore.garments.count) 件")
                .font(.headline)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .overlay {
                    Capsule()
                        .stroke(Color.wearWiseInk, lineWidth: 1.5)
                }
                .accessibilityLabel("衣柜中共有 \(garmentStore.garments.count) 件衣物")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            GarmentPlaceholderView(name: "还没有衣物照片", systemImage: "cabinet")
                .frame(maxWidth: 290)

            VStack(spacing: 6) {
                Text("先拍下第一件衣物")
                    .font(.title3.weight(.bold))
                Text("照片只保存在本机。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var wardrobeGroups: some View {
        ForEach(GarmentSlot.allCases.sorted { $0.displayOrder < $1.displayOrder }) { slot in
            let items = garmentStore.garments.filter { $0.slot == slot }
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(slot.label, systemImage: slot.systemImage)
                            .font(.title3.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("\(items.count) 件")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(items) { garment in
                            Button {
                                activeSheet = .edit(garment)
                            } label: {
                                GarmentCard(garment: garment)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("编辑衣物类型和标签")
                        }
                    }
                }
            }
        }
    }
}

private struct GarmentCard: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GarmentPhotoView(garment: garment)

            VStack(alignment: .leading, spacing: 5) {
                Text(garment.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Label(garment.colorLabel, systemImage: "paintpalette")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(garment.formalityLabel, systemImage: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(garment.source.label, systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Label("编辑", systemImage: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            Color.wearWiseBackground,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.wearWiseBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(garment.name)，\(garment.slot.label)，\(garment.colorLabel)，\(garment.formalityLabel)，\(garment.source.label)"
        )
    }
}

private enum WardrobeSheet: Identifiable {
    case add
    case edit(Garment)

    var id: String {
        switch self {
        case .add: "add"
        case let .edit(garment): "edit-\(garment.id.uuidString)"
        }
    }
}

struct GarmentPhotoView: View {
    @EnvironmentObject private var garmentStore: GarmentStore

    let garment: Garment
    var thumbnail = true

    var body: some View {
        Group {
            if let image = garmentStore.image(for: garment, thumbnail: thumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("\(garment.name)的照片")
            } else {
                GarmentPlaceholderView(
                    name: garment.name,
                    systemImage: "photo.badge.exclamationmark"
                )
                .accessibilityLabel("\(garment.name)的照片缺失")
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.wearWiseBorder, lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct GarmentPlaceholderView: View {
    let name: String
    let systemImage: String

    var body: some View {
        ZStack {
            Color.wearWiseSurface

            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .medium))
                    .accessibilityHidden(true)

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 12)

                Text("照片缺失")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.wearWiseInk,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                )
        }
    }
}
