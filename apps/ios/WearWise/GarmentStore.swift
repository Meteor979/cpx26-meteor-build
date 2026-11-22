import Combine
import Foundation
import UIKit

enum GarmentStoreError: LocalizedError {
    case garmentNotFound
    case incompleteImageUpdate

    var errorDescription: String? {
        switch self {
        case .garmentNotFound:
            "The clothing item could not be found."
        case .incompleteImageUpdate:
            "The image data is incomplete. Choose the photo again."
        }
    }
}

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
            errorMessage = "Wardrobe data could not be loaded: \(error.localizedDescription)"
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

    @discardableResult
    func updateGarment(
        id: UUID,
        name: String,
        slot: GarmentSlot,
        category: String,
        colors: [String],
        pattern: String,
        fit: String,
        material: String,
        formalityScore: Int,
        warmthScore: Int,
        photoData: Data? = nil,
        thumbnailData: Data? = nil
    ) throws -> Garment {
        guard let index = garments.firstIndex(where: { $0.id == id }) else {
            throw GarmentStoreError.garmentNotFound
        }
        guard (photoData == nil) == (thumbnailData == nil) else {
            throw GarmentStoreError.incompleteImageUpdate
        }

        let current = garments[index]
        let photoURL = imageURL(for: current.localPhotoPath)
        let thumbnailURL = imageURL(for: current.thumbnailPath)
        let oldPhoto = try? Data(contentsOf: photoURL)
        let oldThumbnail = try? Data(contentsOf: thumbnailURL)

        let updated = Garment(
            id: current.id,
            localPhotoPath: current.localPhotoPath,
            thumbnailPath: current.thumbnailPath,
            capturedAt: current.capturedAt,
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
            source: current.source
        )

        do {
            if let photoData, let thumbnailData {
                try photoData.write(to: photoURL, options: .atomic)
                try thumbnailData.write(to: thumbnailURL, options: .atomic)
            }
            garments[index] = updated
            try saveMetadata()
            return updated
        } catch {
            garments[index] = current
            restore(oldPhoto, to: photoURL)
            restore(oldThumbnail, to: thumbnailURL)
            throw error
        }
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

    private func restore(_ data: Data?, to url: URL) {
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }
}
