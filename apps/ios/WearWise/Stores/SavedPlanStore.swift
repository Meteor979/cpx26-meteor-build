import Combine
import Foundation

@MainActor
final class SavedPlanStore: ObservableObject {
    @Published private(set) var plans: [SavedPlan] = []
    @Published private(set) var errorMessage: String?

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let metadataURL: URL

    var latest: SavedPlan? {
        plans.first
    }

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
            ?? baseDirectory.appendingPathComponent("WearWisePlans", isDirectory: true)
        self.rootDirectory = directory
        self.metadataURL = directory.appendingPathComponent("plans.json")

        do {
            try ensureDirectory()
            try load()
        } catch {
            errorMessage = "最近方案读取失败：\(error.localizedDescription)"
        }
    }

    func save(_ plan: SavedPlan) throws {
        try ensureDirectory()
        plans.insert(plan, at: 0)
        do {
            try persist()
        } catch {
            plans.removeAll { $0.id == plan.id }
            throw error
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    private func load() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            plans = []
            return
        }
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        plans = try decoder.decode([SavedPlan].self, from: data)
            .sorted { $0.savedAt > $1.savedAt }
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(plans).write(to: metadataURL, options: .atomic)
    }
}
