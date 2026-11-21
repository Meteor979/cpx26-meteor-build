import PhotosUI
import SwiftUI
import UIKit

struct AddGarmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var garmentStore: GarmentStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showsCamera = false
    @State private var isReadingPhoto = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var name = ""
    @State private var slot = GarmentSlot.top
    @State private var category = ""
    @State private var colorText = ""
    @State private var pattern = ""
    @State private var fit = ""
    @State private var material = ""
    @State private var formalityScore = 3
    @State private var warmthScore = 3
    @State private var showsMoreDetails = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canSave: Bool {
        imageData != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isReadingPhoto
            && !isSaving
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
            .navigationTitle("添加衣物")
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
                Text("模拟器没有相机，可从相册选择一张测试图片。")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("衣物类型")
                    .font(.subheadline.weight(.semibold))
                Picker("衣物类型", selection: $slot) {
                    ForEach(GarmentSlot.allCases) { slot in
                        Label(slot.label, systemImage: slot.systemImage)
                            .tag(slot)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 14)
                .background(
                    Color.wearWiseSurface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.wearWiseBorder, lineWidth: 1)
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
                isSaving
                    ? "正在保存"
                    : canSave
                        ? "保存衣物"
                        : "请先选择照片并填写名称",
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
        guard let imageData, canSave else {
            return
        }
        isSaving = true
        defer { isSaving = false }

        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try GarmentImageProcessor.prepare(imageData)
            }.value

            let colors = colorText
                .split(whereSeparator: { "，,、".contains($0) })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

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
