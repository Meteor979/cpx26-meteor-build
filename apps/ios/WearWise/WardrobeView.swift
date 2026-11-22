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
                    Label("Add clothing", systemImage: "camera.fill")
                }
                .buttonStyle(WearWisePrimaryButtonStyle())
                .accessibilityHint("Take a photo or choose one from your library")

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
        .navigationTitle("My wardrobe")
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
            "Wardrobe problem",
            isPresented: Binding(
                get: { garmentStore.errorMessage != nil },
                set: { if !$0 { garmentStore.clearError() } }
            )
        ) {
            Button("OK") {
                garmentStore.clearError()
            }
        } message: {
            Text(garmentStore.errorMessage ?? "Please try again.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Photo wardrobe")
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Text("\(garmentStore.garments.count) items")
                .font(.headline)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .overlay {
                    Capsule()
                        .stroke(Color.wearWiseInk, lineWidth: 1.5)
                }
                .accessibilityLabel(
                    "The wardrobe contains \(garmentStore.garments.count) items"
                )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            GarmentPlaceholderView(name: "No clothing photos yet", systemImage: "cabinet")
                .frame(maxWidth: 290)

            VStack(spacing: 6) {
                Text("Add your first clothing photo")
                    .font(.title3.weight(.bold))
                Text("Photos stay on this device.")
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
                        Text("\(items.count) items")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(items) { garment in
                            VStack(spacing: 8) {
                                SwipeableGarmentCard(garment: garment) {
                                    activeSheet = .edit(garment)
                                }

                                Button {
                                    activeSheet = .edit(garment)
                                } label: {
                                    Label("Edit clothing", systemImage: "pencil")
                                }
                                .buttonStyle(WearWiseSecondaryButtonStyle())
                                .accessibilityHint("Change the clothing type and tags")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SwipeableGarmentCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let garment: Garment
    let onEdit: () -> Void

    @State private var offset: CGFloat = 0
    private let actionWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                onEdit()
                closeActions()
            } label: {
                VStack(spacing: 7) {
                    Image(systemName: "pencil")
                        .font(.title3.weight(.semibold))
                    Text("Edit")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.wearWiseInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(garment.name)")

            GarmentCard(garment: garment)
                .background(Color.wearWiseBackground)
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if offset < 0 {
                        closeActions()
                    } else {
                        onEdit()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard
                                abs(value.translation.width)
                                    > abs(value.translation.height)
                            else {
                                return
                            }
                            offset = min(
                                0,
                                max(-actionWidth, offset + value.translation.width)
                            )
                        }
                        .onEnded { value in
                            guard
                                abs(value.translation.width)
                                    > abs(value.translation.height)
                            else {
                                return
                            }
                            offset = value.translation.width < -36
                                ? -actionWidth
                                : 0
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: offset
        )
        .accessibilityHint("Swipe left to reveal editing")
    }

    private func closeActions() {
        offset = 0
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

                Label("Tap or swipe to edit", systemImage: "pencil")
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
        .contentShape(Rectangle())
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
                    .accessibilityLabel("Photo of \(garment.name)")
            } else {
                GarmentPlaceholderView(
                    name: garment.name,
                    systemImage: "photo.badge.exclamationmark"
                )
                .accessibilityLabel("\(garment.name), photo missing")
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

                Text("Photo missing")
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
