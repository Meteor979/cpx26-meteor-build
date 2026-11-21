import Combine
import Foundation
import UIKit

@MainActor
final class GarmentStore: ObservableObject {
    @Published private(set) var garments: [Garment] = []
    @Published private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let metadataURL: URL

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        let baseDirectory =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory =
            rootDirectory
            ?? baseDirectory.appendingPathComponent("WearWiseGarments", isDirectory: true)

        self.rootDirectory = directory
        self.metadataURL = directory.appendingPathComponent("garments.json")

        do {
            try ensureDirectory()
            try loadMetadata()
        } catch {
            errorMessage = "衣柜数据读取失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func addGarment(
        name: String,
        slot: GarmentSlot,
        category: String,
        colors: [String],
        pattern: String,
        fit: String,
        material: String,
        formalityScore: Int,
        warmthScore: Int,
        photoData: Data,
        thumbnailData: Data,
        source: GarmentSource = .manual
    ) throws -> Garment {
        try ensureDirectory()

        let id = UUID()
        let photoFilename = "\(id.uuidString).jpg"
        let thumbnailFilename = "\(id.uuidString)-thumb.jpg"
        let photoURL = rootDirectory.appendingPathComponent(photoFilename)
        let thumbnailURL = rootDirectory.appendingPathComponent(thumbnailFilename)

        let garment = Garment(
            id: id,
            localPhotoPath: photoFilename,
            thumbnailPath: thumbnailFilename,
            capturedAt: Date(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            slot: slot,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            colors: colors.filter { !$0.isEmpty },
            pattern: pattern.trimmingCharacters(in: .whitespacesAndNewlines),
            fit: fit.trimmingCharacters(in: .whitespacesAndNewlines),
            material: material.trimmingCharacters(in: .whitespacesAndNewlines),
            formalityScore: min(5, max(1, formalityScore)),
            warmthScore: min(5, max(1, warmthScore)),
            userConfirmed: true,
            source: source
        )

        do {
            try photoData.write(to: photoURL, options: .atomic)
            try thumbnailData.write(to: thumbnailURL, options: .atomic)
            garments.insert(garment, at: 0)
            try saveMetadata()
            return garment
        } catch {
            garments.removeAll { $0.id == id }
            try? fileManager.removeItem(at: photoURL)
            try? fileManager.removeItem(at: thumbnailURL)
            throw error
        }
    }

    func image(for garment: Garment, thumbnail: Bool = true) -> UIImage? {
        let primary = imageURL(
            for: thumbnail ? garment.thumbnailPath : garment.localPhotoPath
        )
        if let image = UIImage(contentsOfFile: primary.path) {
            return image
        }

        let fallback = imageURL(
            for: thumbnail ? garment.localPhotoPath : garment.thumbnailPath
        )
        return UIImage(contentsOfFile: fallback.path)
    }

    func clearError() {
        errorMessage = nil
    }

    private func imageURL(for filename: String) -> URL {
        rootDirectory.appendingPathComponent(
            URL(fileURLWithPath: filename).lastPathComponent,
            isDirectory: false
        )
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    private func loadMetadata() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            garments = []
            return
        }

        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        garments = try decoder.decode([Garment].self, from: data)
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    private func saveMetadata() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(garments)
        try data.write(to: metadataURL, options: .atomic)
    }
}
