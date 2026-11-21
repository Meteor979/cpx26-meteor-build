import Foundation

enum OutfitSource: String, Codable, Hashable {
    case mock
    case remoteAPI = "remote_api"
    case fallback
    case manual

    var label: String {
        switch self {
        case .mock: "本地样例"
        case .remoteAPI: "后端结果"
        case .fallback: "本地备用"
        case .manual: "手动调整"
        }
    }
}

struct Outfit: Codable, Identifiable, Hashable {
    let id: String
    let itemIDs: [String]
    let title: String
    let reasons: [String]
    let tradeoffs: [String]
    let source: OutfitSource
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case itemIDs = "itemIds"
        case title
        case reasons
        case tradeoffs
        case source
        case score
    }
}

struct RecommendationResponse: Codable {
    let outfits: [Outfit]
    let requestedCount: Int
    let resultCountReason: String
    let fallbackUsed: Bool
    let warning: String?
    let provider: String?
    let generatedAt: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case outfits
        case requestedCount
        case resultCountReason
        case fallbackUsed
        case warning
        case provider
        case generatedAt
        case requestID = "requestId"
    }
}

struct RecommendationGarment: Encodable {
    let id: String
    let brand: String?
    let productName: String?
    let slot: GarmentSlot
    let category: String
    let colors: [String]
    let pattern: String?
    let fit: String?
    let material: String?
    let formalityScore: Int
    let warmthScore: Int
    let userConfirmed: Bool
}

struct RecommendationRequest: Encodable {
    let requestID: String
    let presetID: String?
    let occasion: String
    let weather: WeatherData
    let formality: FormalityBand
    let garments: [RecommendationGarment]

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case presetID = "presetId"
        case occasion
        case weather
        case formality
        case garments
    }
}

struct OutfitRevisionRequest: Encodable {
    let requestID: String
    let presetID: String?
    let occasion: String
    let weather: WeatherData
    let formality: FormalityBand
    let garments: [RecommendationGarment]
    let baseItemIDs: [String]
    let replacementItemID: String

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case presetID = "presetId"
        case occasion
        case weather
        case formality
        case garments
        case baseItemIDs = "baseItemIds"
        case replacementItemID = "replacementItemId"
    }
}

struct OutfitRevisionResponse: Codable {
    let outfit: Outfit
    let fallbackUsed: Bool
    let warning: String?
    let provider: String?
    let generatedAt: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case outfit
        case fallbackUsed
        case warning
        case provider
        case generatedAt
        case requestID = "requestId"
    }
}

struct ResolvedOutfitItem: Identifiable {
    let remoteID: String
    let garment: Garment?

    var id: String { remoteID }

    var displayName: String {
        garment?.name ?? "无法映射的衣物 \(remoteID.prefix(8))"
    }

    var slot: GarmentSlot? {
        garment?.slot
    }

    var mappingWarning: String? {
        garment == nil ? "照片或衣物记录无法映射" : nil
    }
}

struct ResolvedOutfit: Identifiable {
    let outfit: Outfit
    let items: [ResolvedOutfitItem]
    let isManualAdjusted: Bool

    var id: String { outfit.id }

    var sourceLabel: String {
        isManualAdjusted ? OutfitSource.manual.label : outfit.source.label
    }
}

struct SavedPlan: Codable, Identifiable {
    let outfitID: String
    let outfitTitle: String
    let itemIDs: [String]
    let occasion: String
    let formality: FormalityBand
    let weather: WeatherData
    let recommendationSource: String
    let savedAt: Date

    var id: String {
        "\(outfitID)-\(savedAt.timeIntervalSince1970)"
    }
}

struct RecommendationContext {
    let occasion: String
    let presetID: String?
    let formality: FormalityBand
    let weather: WeatherData
}
