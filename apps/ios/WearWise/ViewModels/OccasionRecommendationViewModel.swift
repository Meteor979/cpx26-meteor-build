import Combine
import Foundation

@MainActor
final class OccasionRecommendationViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var formality: FormalityBand = .smartCasual
    @Published private(set) var profile: OccasionPreset?
    @Published private(set) var resolvedProfileName = ""
    @Published private(set) var resolvedQuery = ""
    @Published private(set) var resolutionSource = ""
    @Published private(set) var presets = LocalPresetCatalog.choices
    @Published private(set) var recommendations: [ResolvedOutfit] = []
    @Published private(set) var resultCountReason = ""
    @Published private(set) var recommendationWarning: String?
    @Published private(set) var selectedOutfitID: String?
    @Published private(set) var isResolving = false
    @Published private(set) var isGenerating = false
    @Published private(set) var isRevising = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var operationMessage = ""
    @Published private(set) var contextChanged = false
    @Published private(set) var recommendationTimedOut = false
    @Published var showsRecommendations = false

    private let presetService: PresetServiceProtocol
    private let occasionService: OccasionServiceProtocol
    private let recommendationService: RecommendationServiceProtocol
    private let weather = WeatherData.demo
    private var loadingTask: Task<Void, Never>?

    static let resolvingMessages = [
        "Resolving your occasion...",
        "AI is refining the context...",
        "Using local rules..."
    ]
    static let recommendationMessages = [
        "Building three outfit options...",
        "Comparing formality and weather...",
        "Checking your wardrobe photos..."
    ]

    init(
        presetService: PresetServiceProtocol = PresetService(),
        occasionService: OccasionServiceProtocol = OccasionService(),
        recommendationService: RecommendationServiceProtocol = RecommendationService()
    ) {
        self.presetService = presetService
        self.occasionService = occasionService
        self.recommendationService = recommendationService
    }

    var canResolve: Bool {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.count <= 240 && !isResolving
    }

    var resolutionHighlights: String {
        profile?.styleKeywords.prefix(3).joined(separator: "、") ?? ""
    }

    func loadPresets() async {
        let result = await presetService.loadPresets()
        let requiredIDs = Set(LocalPresetCatalog.choices.map(\.id))
        let extras = result.response.presets.filter {
            !requiredIDs.contains($0.id)
        }
        presets = LocalPresetCatalog.choices + Array(extras.prefix(2))
    }

    func usePreset(_ preset: OccasionPreset) {
        resolvedQuery = preset.name
        query = preset.name
        profile = nil
        resolvedProfileName = ""
        resolutionSource = ""
        formality = preset.targetFormality
        contextChanged = false
        recommendationTimedOut = false
        errorMessage = nil
    }

    func queryDidChange() {
        if query.trimmingCharacters(in: .whitespacesAndNewlines) != resolvedQuery {
            profile = nil
            resolvedProfileName = ""
            resolutionSource = ""
            resolvedQuery = ""
            formality = .smartCasual
            contextChanged = false
            recommendationTimedOut = false
            errorMessage = nil
        }
    }

    func resolveOccasion() async {
        guard canResolve else {
            errorMessage = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Enter an occasion first."
                : "The occasion must be 240 characters or fewer."
            return
        }
        isResolving = true
        errorMessage = nil
        startLoading(messages: Self.resolvingMessages)
        defer {
            isResolving = false
            stopLoading()
        }

        do {
            let result = try await occasionService.resolve(
                query: query,
                formalityHint: formality
            )
            profile = result.response.profile
            resolvedProfileName = result.response.profile.name
            resolvedQuery = result.response.query
            formality = result.response.profile.targetFormality
            resolutionSource = result.sourceLabel
            contextChanged = false
            recommendationTimedOut = false
        } catch {
            if Task.isCancelled || error is CancellationError {
                return
            }
            errorMessage = displayMessage(
                for: error,
                fallback: "The occasion could not be resolved. Check the input and try again."
            )
        }
    }

    func adjustFormality(_ band: FormalityBand) {
        formality = band
        contextChanged = profile != nil && band != profile?.targetFormality
        recommendationTimedOut = false
        errorMessage = nil
    }

    func generateRecommendations(garments: [Garment]) async {
        guard !isGenerating else {
            return
        }
        let missing = missingRequiredSlots(in: garments)
        guard missing.isEmpty else {
            errorMessage =
                "Add these wardrobe items first: "
                + missing.map(\.label).joined(separator: ", ")
            return
        }

        isGenerating = true
        errorMessage = nil
        recommendationTimedOut = false
        startLoading(messages: Self.recommendationMessages)
        defer {
            isGenerating = false
            stopLoading()
        }

        do {
            let response = try await recommendationService.recommend(
                context: recommendationContext,
                garments: garments
            )
            apply(response: response, garments: garments)
            if recommendations.isEmpty {
                errorMessage = "The wardrobe cannot form a complete outfit yet."
            }
        } catch {
            if Task.isCancelled || error is CancellationError {
                return
            }
            if let apiError = error as? APIError, apiError.isTimeout {
                recommendationTimedOut = true
                errorMessage =
                    "The AI request timed out. Try again or use local rules."
                return
            }
            errorMessage = displayMessage(
                for: error,
                fallback: "Outfits could not be generated. Try again or use local rules."
            )
        }
    }

    func retryRecommendations(garments: [Garment]) async {
        await generateRecommendations(garments: garments)
    }

    func useLocalRecommendations(garments: [Garment]) {
        recommendationTimedOut = false
        errorMessage = nil
        let response = LocalRecommendationEngine.recommend(
            context: recommendationContext,
            garments: garments
        )
        apply(response: response, garments: garments)
    }

    func cancelOperations() {
        loadingTask?.cancel()
        loadingTask = nil
        operationMessage = ""
        isResolving = false
        isGenerating = false
    }

    func outfit(id: String) -> ResolvedOutfit? {
        recommendations.first { $0.id == id }
    }

    func selectOutfit(id: String) {
        selectedOutfitID = id
    }

    func revise(
        outfitID: String,
        replacement: Garment,
        garments: [Garment]
    ) async {
        guard
            let index = recommendations.firstIndex(where: { $0.id == outfitID }),
            !isRevising
        else {
            return
        }
        isRevising = true
        errorMessage = nil
        defer { isRevising = false }

        do {
            let response = try await recommendationService.revise(
                context: recommendationContext,
                currentOutfit: recommendations[index].outfit,
                replacement: replacement,
                garments: garments
            )
            let resolved = Self.resolveOutfit(
                response.outfit,
                garments: garments,
                forceManual: response.outfit.source == .manual,
                provider: response.provider,
                fallbackUsed: response.fallbackUsed
            )
            recommendations[index] = resolved
            selectedOutfitID = resolved.id
        } catch {
            errorMessage = displayMessage(
                for: error,
                fallback: "The item could not be replaced. Your current outfit is unchanged."
            )
        }
    }

    func makeSavedPlan(from outfit: ResolvedOutfit) -> SavedPlan {
        SavedPlan(
            outfitID: outfit.outfit.id,
            outfitTitle: outfit.outfit.title,
            itemIDs: outfit.outfit.itemIDs,
            occasion: resolvedQuery.isEmpty ? query : resolvedQuery,
            formality: formality,
            weather: weather,
            recommendationSource: outfit.sourceLabel,
            savedAt: Date()
        )
    }

    func clearError() {
        errorMessage = nil
    }

    static func resolveOutfits(
        _ outfits: [Outfit],
        garments: [Garment],
        provider: String? = nil,
        fallbackUsed: Bool = false
    ) -> [ResolvedOutfit] {
        outfits.map {
            resolveOutfit(
                $0,
                garments: garments,
                forceManual: $0.source == .manual,
                provider: provider,
                fallbackUsed: fallbackUsed
            )
        }
    }

    static func resolveOutfit(
        _ outfit: Outfit,
        garments: [Garment],
        forceManual: Bool = false,
        provider: String? = nil,
        fallbackUsed: Bool = false
    ) -> ResolvedOutfit {
        let garmentsByID = Dictionary(
            uniqueKeysWithValues: garments.map {
                ($0.id.uuidString.lowercased(), $0)
            }
        )
        return ResolvedOutfit(
            outfit: outfit,
            items: outfit.itemIDs.map {
                ResolvedOutfitItem(
                    remoteID: $0,
                    garment: garmentsByID[$0.lowercased()]
                )
            },
            isManualAdjusted: forceManual,
            sourceLabelOverride: sourceLabel(
                for: outfit,
                provider: provider,
                fallbackUsed: fallbackUsed
            )
        )
    }

    var contextSummary: String {
        "\(formality.label) · \(weather.summary)"
    }

    private var recommendationContext: RecommendationContext {
        RecommendationContext(
            occasion: resolvedQuery.isEmpty ? query : resolvedQuery,
            presetID: profile?.id,
            formality: formality,
            weather: weather
        )
    }

    private static func sourceLabel(
        for outfit: Outfit,
        provider: String?,
        fallbackUsed: Bool
    ) -> String {
        if outfit.source == .fallback {
            return "Fallback result"
        }
        if outfit.source == .mock {
            return "Local rules"
        }
        if fallbackUsed {
            return "Fallback result"
        }
        let normalizedProvider = provider?.lowercased() ?? ""
        if normalizedProvider.contains("rule")
            || normalizedProvider.contains("mock")
        {
            return "Local rules"
        }
        return "AI result"
    }

    private func apply(
        response: RecommendationResponse,
        garments: [Garment]
    ) {
        recommendations = Self.resolveOutfits(
            response.outfits,
            garments: garments,
            provider: response.provider,
            fallbackUsed: response.fallbackUsed
        )
        resultCountReason = response.resultCountReason
        recommendationWarning = response.warning
        selectedOutfitID = recommendations.first?.id
        showsRecommendations = !recommendations.isEmpty
        contextChanged = false
    }

    private func startLoading(messages: [String]) {
        loadingTask?.cancel()
        operationMessage = messages.first ?? ""
        loadingTask = Task { @MainActor [weak self] in
            for message in messages.dropFirst() {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled, let self else {
                    return
                }
                self.operationMessage = message
            }
        }
    }

    private func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        operationMessage = ""
    }

    private func displayMessage(
        for error: Error,
        fallback: String
    ) -> String {
        if let apiError = error as? APIError {
            if apiError.isTimeout {
                return "The AI request timed out. Try again or use local rules."
            }
            if apiError.statusCode == 422 {
                return "Some information is invalid. Check the occasion and try again."
            }
            if case .network = apiError {
                return "The backend is unavailable. Local rules remain available."
            }
        }
        return fallback
    }

    private func missingRequiredSlots(in garments: [Garment]) -> [GarmentSlot] {
        let available = Set(garments.map(\.slot))
        return [.top, .bottom, .shoes].filter { !available.contains($0) }
    }
}
