import Combine
import Foundation

@MainActor
final class OccasionRecommendationViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var formality: FormalityBand = .smartCasual
    @Published private(set) var profile: OccasionPreset?
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
    @Published private(set) var weatherContext: WeatherContext
    @Published var showsRecommendations = false

    private let presetService: PresetServiceProtocol
    private let occasionService: OccasionServiceProtocol
    private let recommendationService: RecommendationServiceProtocol

    init(
        presetService: PresetServiceProtocol = PresetService(),
        occasionService: OccasionServiceProtocol = OccasionService(),
        recommendationService: RecommendationServiceProtocol = RecommendationService(),
        weatherContext: WeatherContext = .demo
    ) {
        self.presetService = presetService
        self.occasionService = occasionService
        self.recommendationService = recommendationService
        self.weatherContext = weatherContext
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
        resolutionSource = ""
        formality = preset.targetFormality
    }

    func queryDidChange() {
        if query.trimmingCharacters(in: .whitespacesAndNewlines) != resolvedQuery {
            profile = nil
            resolutionSource = ""
            resolvedQuery = ""
            formality = .smartCasual
        }
    }

    func resolveOccasion() async {
        guard canResolve else {
            errorMessage = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "请先输入场合。"
                : "场合不能超过 240 个字符。"
            return
        }
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        do {
            let result = try await occasionService.resolve(
                query: query,
                formalityHint: formality
            )
            profile = result.response.profile
            resolvedQuery = result.response.query
            formality = result.response.profile.targetFormality
            resolutionSource = result.sourceLabel
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func adjustFormality(_ band: FormalityBand) {
        formality = band
    }

    func updateWeatherContext(_ context: WeatherContext) {
        weatherContext = context
    }

    func generateRecommendations(garments: [Garment]) async {
        guard !isGenerating else {
            return
        }
        let missing = missingRequiredSlots(in: garments)
        guard missing.isEmpty else {
            errorMessage = "还需要添加：\(missing.map(\.label).joined(separator: "、"))。"
            return
        }

        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let response = try await recommendationService.recommend(
                context: recommendationContext,
                garments: garments
            )
            recommendations = Self.resolveOutfits(
                response.outfits,
                garments: garments
            )
            resultCountReason = response.resultCountReason
            recommendationWarning = response.warning
            selectedOutfitID = recommendations.first?.id
            showsRecommendations = !recommendations.isEmpty
            if recommendations.isEmpty {
                errorMessage = "当前衣柜无法组成完整搭配。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
                forceManual: response.outfit.source == .manual
            )
            recommendations[index] = resolved
            selectedOutfitID = resolved.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeSavedPlan(from outfit: ResolvedOutfit) -> SavedPlan {
        SavedPlan(
            outfitID: outfit.outfit.id,
            outfitTitle: outfit.outfit.title,
            itemIDs: outfit.outfit.itemIDs,
            occasion: resolvedQuery.isEmpty ? query : resolvedQuery,
            formality: formality,
            weather: weatherContext.weather,
            recommendationSource: outfit.sourceLabel,
            savedAt: Date()
        )
    }

    func clearError() {
        errorMessage = nil
    }

    static func resolveOutfits(
        _ outfits: [Outfit],
        garments: [Garment]
    ) -> [ResolvedOutfit] {
        outfits.map {
            resolveOutfit(
                $0,
                garments: garments,
                forceManual: $0.source == .manual
            )
        }
    }

    static func resolveOutfit(
        _ outfit: Outfit,
        garments: [Garment],
        forceManual: Bool = false
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
            isManualAdjusted: forceManual
        )
    }

    var contextSummary: String {
        "\(formality.label) · \(weatherContext.weather.summary)"
    }

    private var recommendationContext: RecommendationContext {
        RecommendationContext(
            occasion: resolvedQuery.isEmpty ? query : resolvedQuery,
            presetID: profile?.id,
            formality: formality,
            weather: weatherContext.weather
        )
    }

    private func missingRequiredSlots(in garments: [Garment]) -> [GarmentSlot] {
        let available = Set(garments.map(\.slot))
        return [.top, .bottom, .shoes].filter { !available.contains($0) }
    }
}
