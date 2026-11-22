import PhotosUI
import SwiftUI
import UIKit

struct AddGarmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var garmentStore: GarmentStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let editingGarment: Garment?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showsCamera = false
    @State private var isReadingPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var name: String
    @State private var slot: GarmentSlot
    @State private var category: String
    @State private var colorText: String
    @State private var pattern: String
    @State private var fit: String
    @State private var material: String
    @State private var formalityScore: Int
    @State private var warmthScore: Int
    @State private var showsMoreDetails = false

    init(editingGarment: Garment? = nil) {
        self.editingGarment = editingGarment
        _name = State(initialValue: editingGarment?.name ?? "")
        _slot = State(initialValue: editingGarment?.slot ?? .top)
        _category = State(initialValue: editingGarment?.category ?? "")
        _colorText = State(
            initialValue: editingGarment?.colors.joined(separator: "、") ?? ""
        )
        _pattern = State(initialValue: editingGarment?.pattern ?? "")
        _fit = State(initialValue: editingGarment?.fit ?? "")
        _material = State(initialValue: editingGarment?.material ?? "")
        _formalityScore = State(initialValue: editingGarment?.formalityScore ?? 3)
        _warmthScore = State(initialValue: editingGarment?.warmthScore ?? 3)
    }

    private var typeColumns: [GridItem] {
        dynamicTypeSize >= .xxxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canSave: Bool {
        (imageData != nil || editingGarment != nil)
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isReadingPhoto
            && !isSaving
    }

    private var saveButtonTitle: String {
        if isSaving {
            return "Saving"
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a clothing name"
        }
        if imageData == nil, editingGarment == nil {
            return "Choose a photo first"
        }
        return editingGarment == nil ? "Save clothing" : "Save changes"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoSection
                    basicFields
                    reviewFields
                    saveButton
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .background(Color.wearWiseBackground)
            .navigationTitle(
                editingGarment == nil ? "Add clothing" : "Edit clothing"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showsCamera) {
                CameraCapturePicker(
                    onCapture: { data in
                        imageData = data
                        showsCamera = false
                    },
                    onCancel: {
                        showsCamera = false
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) { _, item in
                loadPhoto(item)
            }
            .alert(
                "Unable to save clothing",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clothing photo")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            photoPreview
                .frame(maxWidth: 330)
                .frame(maxWidth: .infinity)

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose from library", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())

            Button {
                showsCamera = true
            } label: {
                Label(
                    cameraAvailable ? "Take clothing photo" : "No camera on this device",
                    systemImage: cameraAvailable ? "camera.fill" : "camera.badge.ellipsis"
                )
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())
            .disabled(!cameraAvailable)

            if !cameraAvailable {
                Text("Use the photo library in Simulator.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isReadingPhoto {
                Label("Reading photo", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if
            let imageData,
            let image = UIImage(data: imageData)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.wearWiseInk, lineWidth: 2)
                }
                .accessibilityLabel("Clothing photo to save")
        } else if
            let editingGarment,
            let image = garmentStore.image(for: editingGarment, thumbnail: false)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.wearWiseInk, lineWidth: 2)
                }
                .accessibilityLabel("Current clothing photo")
        } else {
            ZStack {
                Color.wearWiseSurface
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 46, weight: .medium))
                        .accessibilityHidden(true)
                    Text("Your photo preview will appear here")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        Color.wearWiseInk,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 5])
                    )
            }
        }
    }

    private var basicFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic details")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            field("Clothing name", text: $name, prompt: "e.g. Light blue oxford shirt")

            VStack(alignment: .leading, spacing: 10) {
                Text("Clothing type")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: typeColumns, spacing: 10) {
                    ForEach(GarmentSlot.allCases) { slot in
                        Button {
                            self.slot = slot
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: slot.systemImage)
                                    .accessibilityHidden(true)
                                Text(slot.label)
                                Spacer(minLength: 4)
                                if self.slot == slot {
                                    Image(systemName: "checkmark.circle.fill")
                                        .accessibilityHidden(true)
                                }
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(
                                self.slot == slot
                                    ? Color(uiColor: .systemBackground)
                                    : Color.wearWiseInk
                            )
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                self.slot == slot
                                    ? Color.wearWiseInk
                                    : Color.wearWiseSurface,
                                in: RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                                .stroke(
                                    Color.wearWiseInk,
                                    lineWidth: self.slot == slot ? 2 : 1
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(slot.label), \(self.slot == slot ? "selected" : "not selected")"
                        )
                    }
                }
            }

            field(
                "Color name",
                text: $colorText,
                prompt: "e.g. Light blue, navy"
            )

            Stepper(value: $formalityScore, in: 1...5) {
                Label("Formality \(formalityScore)/5", systemImage: "chart.bar.fill")
                    .font(.body)
            }
            .frame(minHeight: 52)
        }
    }

    private var reviewFields: some View {
        DisclosureGroup(isExpanded: $showsMoreDetails) {
            VStack(spacing: 14) {
                field("Category", text: $category, prompt: "e.g. Shirt")
                field("Pattern", text: $pattern, prompt: "e.g. Solid, striped")
                field("Fit", text: $fit, prompt: "e.g. Regular, relaxed")
                field("Material", text: $material, prompt: "e.g. Cotton, wool blend")

                Stepper(value: $warmthScore, in: 1...5) {
                    Label("Warmth \(warmthScore)/5", systemImage: "thermometer.medium")
                        .font(.body)
                }
                .frame(minHeight: 52)
            }
            .padding(.top, 14)
        } label: {
            Label("Additional details", systemImage: "tag")
                .font(.headline)
        }
        .padding(16)
        .background(
            Color.wearWiseSurface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var saveButton: some View {
        Button {
            Task {
                await save()
            }
        } label: {
            Label(
                saveButtonTitle,
                systemImage: isSaving ? "hourglass" : "checkmark.circle.fill"
            )
        }
        .buttonStyle(WearWisePrimaryButtonStyle())
        .disabled(!canSave)
        .accessibilityHint("Save the photo and reviewed clothing details locally")
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(
                    Color.wearWiseSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.wearWiseBorder, lineWidth: 1)
                }
                .accessibilityLabel(title)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else {
            return
        }
        isReadingPhoto = true
        Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw GarmentImageError.unreadableImage
                }
                guard UIImage(data: data) != nil else {
                    throw GarmentImageError.unreadableImage
                }
                imageData = data
            } catch {
                errorMessage = error.localizedDescription
            }
            isReadingPhoto = false
        }
    }

    @MainActor
    private func save() async {
        guard canSave else {
            return
        }
        isSaving = true
        defer { isSaving = false }

        do {
            let prepared: PreparedGarmentImage?
            if let imageData {
                prepared = try await Task.detached(priority: .userInitiated) {
                    try GarmentImageProcessor.prepare(imageData)
                }.value
            } else {
                prepared = nil
            }

            let colors = colorText
                .split(whereSeparator: { "，,、".contains($0) })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if let editingGarment {
                try garmentStore.updateGarment(
                    id: editingGarment.id,
                    name: name,
                    slot: slot,
                    category: category,
                    colors: colors,
                    pattern: pattern,
                    fit: fit,
                    material: material,
                    formalityScore: formalityScore,
                    warmthScore: warmthScore,
                    photoData: prepared?.main,
                    thumbnailData: prepared?.thumbnail
                )
            } else {
                guard let prepared else {
                    throw GarmentImageError.unreadableImage
                }
                try garmentStore.addGarment(
                    name: name,
                    slot: slot,
                    category: category,
                    colors: colors,
                    pattern: pattern,
                    fit: fit,
                    material: material,
                    formalityScore: formalityScore,
                    warmthScore: warmthScore,
                    photoData: prepared.main,
                    thumbnailData: prepared.thumbnail
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CameraCapturePicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
        private let onCapture: (Data) -> Void
        private let onCancel: () -> Void

        init(
            onCapture: @escaping (Data) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard
                let image = info[.originalImage] as? UIImage,
                let data = image.jpegData(compressionQuality: 0.94)
            else {
                onCancel()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
