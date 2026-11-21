import UIKit
import XCTest
@testable import WearWise

final class GarmentStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    @MainActor
    func testGarmentAndPhotosSurviveStoreReload() throws {
        let prepared = try GarmentImageProcessor.prepare(makeTestImageData())
        let store = GarmentStore(rootDirectory: temporaryDirectory)

        try store.addGarment(
            name: "浅蓝牛津衬衫",
            slot: .top,
            category: "衬衫",
            colors: ["浅蓝"],
            pattern: "纯色",
            fit: "常规",
            material: "棉",
            formalityScore: 3,
            warmthScore: 2,
            photoData: prepared.main,
            thumbnailData: prepared.thumbnail
        )

        let reloaded = GarmentStore(rootDirectory: temporaryDirectory)
        let garmentCount = reloaded.garments.count
        let firstGarment = reloaded.garments.first
        let image = firstGarment.flatMap {
            reloaded.image(for: $0)
        }

        XCTAssertEqual(garmentCount, 1)
        XCTAssertEqual(firstGarment?.name, "浅蓝牛津衬衫")
        XCTAssertEqual(firstGarment?.slot, .top)
        XCTAssertNotNil(image)
    }

    @MainActor
    func testMissingPhotoKeepsGarmentAndUsesPlaceholderDataPath() throws {
        let prepared = try GarmentImageProcessor.prepare(makeTestImageData())
        let store = GarmentStore(rootDirectory: temporaryDirectory)
        let garment = try store.addGarment(
            name: "棕色乐福鞋",
            slot: .shoes,
            category: "乐福鞋",
            colors: ["棕色"],
            pattern: "纯色",
            fit: "常规",
            material: "皮革",
            formalityScore: 3,
            warmthScore: 2,
            photoData: prepared.main,
            thumbnailData: prepared.thumbnail
        )

        try FileManager.default.removeItem(
            at: temporaryDirectory.appendingPathComponent(garment.localPhotoPath)
        )
        try FileManager.default.removeItem(
            at: temporaryDirectory.appendingPathComponent(garment.thumbnailPath)
        )

        let reloaded = GarmentStore(rootDirectory: temporaryDirectory)
        let reloadedGarment = try XCTUnwrap(reloaded.garments.first)
        let garmentCount = reloaded.garments.count
        let image = reloaded.image(for: reloadedGarment)

        XCTAssertEqual(garmentCount, 1)
        XCTAssertNil(image)
    }

    @MainActor
    func testEditingGarmentUpdatesSlotAndPreservesPhoto() throws {
        let prepared = try GarmentImageProcessor.prepare(makeTestImageData())
        let store = GarmentStore(rootDirectory: temporaryDirectory)
        let original = try store.addGarment(
            name: "浅蓝衬衫",
            slot: .top,
            category: "衬衫",
            colors: ["浅蓝"],
            pattern: "纯色",
            fit: "常规",
            material: "棉",
            formalityScore: 3,
            warmthScore: 2,
            photoData: prepared.main,
            thumbnailData: prepared.thumbnail
        )

        let updated = try store.updateGarment(
            id: original.id,
            name: "浅蓝衬衫",
            slot: .shoes,
            category: "衬衫",
            colors: ["浅蓝"],
            pattern: "纯色",
            fit: "常规",
            material: "棉",
            formalityScore: 3,
            warmthScore: 2
        )
        let reloaded = GarmentStore(rootDirectory: temporaryDirectory)
        let garmentCount = reloaded.garments.count
        let firstGarment = reloaded.garments.first
        let image = firstGarment.flatMap {
            reloaded.image(for: $0)
        }

        XCTAssertEqual(updated.slot, .shoes)
        XCTAssertEqual(garmentCount, 1)
        XCTAssertEqual(firstGarment?.slot, .shoes)
        XCTAssertNotNil(image)
    }

    private func makeTestImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 100))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 80, height: 100))
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 20, y: 22, width: 40, height: 56))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }
}
