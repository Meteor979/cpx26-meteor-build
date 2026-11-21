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
            return "正在保存"
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写衣物名称"
        }
        if imageData == nil, editingGarment == nil {
            return "请先选择照片"
        }
        return editingGarment == nil ? "保存衣物" : "保存修改"
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
            .navigationTitle(editingGarment == nil ? "添加衣物" : "编辑衣物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
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
                "无法保存衣物",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("知道了") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "请稍后重试。")
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("衣物照片")
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
                Label("从相册选择", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())

            Button {
                showsCamera = true
            } label: {
                Label(
                    cameraAvailable ? "拍摄衣物" : "当前设备没有相机",
                    systemImage: cameraAvailable ? "camera.fill" : "camera.badge.ellipsis"
                )
            }
            .buttonStyle(WearWiseSecondaryButtonStyle())
            .disabled(!cameraAvailable)

            if !cameraAvailable {
                Text("模拟器请从相册选择。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isReadingPhoto {
                Label("正在读取照片", systemImage: "hourglass")
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
                .accessibilityLabel("待保存的衣物照片")
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
                .accessibilityLabel("当前衣物照片")
        } else {
            ZStack {
                Color.wearWiseSurface
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 46, weight: .medium))
                        .accessibilityHidden(true)
                    Text("选择照片后会在这里预览")
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
            Text("基本信息")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            field("衣物名称", text: $name, prompt: "例如：浅蓝牛津衬衫")

            VStack(alignment: .leading, spacing: 10) {
                Text("衣物类型")
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
                            "\(slot.label)，\(self.slot == slot ? "已选择" : "未选择")"
                        )
                    }
                }
            }

            field(
                "颜色名称",
                text: $colorText,
                prompt: "例如：浅蓝、深蓝（用顿号分隔）"
            )

            Stepper(value: $formalityScore, in: 1...5) {
                Label("正式度 \(formalityScore)/5", systemImage: "chart.bar.fill")
                    .font(.body)
            }
            .frame(minHeight: 52)
        }
    }

    private var reviewFields: some View {
        DisclosureGroup(isExpanded: $showsMoreDetails) {
            VStack(spacing: 14) {
                field("类别", text: $category, prompt: "例如：衬衫")
                field("图案", text: $pattern, prompt: "例如：纯色、条纹")
                field("版型", text: $fit, prompt: "例如：常规、宽松")
                field("材质", text: $material, prompt: "例如：棉、羊毛混纺")

                Stepper(value: $warmthScore, in: 1...5) {
                    Label("保暖度 \(warmthScore)/5", systemImage: "thermometer.medium")
                        .font(.body)
                }
                .frame(minHeight: 52)
            }
            .padding(.top, 14)
        } label: {
            Label("补充标签信息", systemImage: "tag")
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
        .accessibilityHint("保存照片和审核后的衣物信息到本机")
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
