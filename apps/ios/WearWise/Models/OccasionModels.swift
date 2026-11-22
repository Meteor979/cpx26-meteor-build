import Foundation

enum FormalityBand: String, Codable, CaseIterable, Identifiable, Hashable {
    case casual
    case smartCasual = "smart_casual"
    case business
    case formal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: "Casual"
        case .smartCasual: "Smart casual"
        case .business: "Business"
        case .formal: "Formal"
        }
    }

    var scoreRange: ClosedRange<Int> {
        switch self {
        case .casual: 1...2
        case .smartCasual: 3...3
        case .business: 4...4
        case .formal: 5...5
        }
    }
}

struct OccasionPreset: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let description: String?
    let targetFormality: FormalityBand
    let allowedFormality: [FormalityBand]
    let requiredSlots: [GarmentSlot]
    let styleKeywords: [String]
    let avoidRules: [String]
    let explanationGuidelines: [String]
    let source: String
    let version: Int
    let generatedAt: String?
}

struct PresetListResponse: Codable {
    let version: Int
    let cached: Bool
    let generatedAt: String?
    let presets: [OccasionPreset]
}

struct OccasionResolveRequest: Encodable {
    let requestID: String
    let query: String
    let locale: String
    let formalityHint: FormalityBand?

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case query
        case locale
        case formalityHint
    }
}

struct OccasionResolveResponse: Codable {
    let query: String
    let profile: OccasionPreset
    let matchType: String
    let confidence: Double
    let cached: Bool
    let alternatives: [OccasionPreset]
    let warning: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case query
        case profile
        case matchType
        case confidence
        case cached
        case alternatives
        case warning
        case requestID = "requestId"
    }
}

struct OccasionResolution {
    let response: OccasionResolveResponse
    let sourceLabel: String
}

enum PresetLoadSource: Equatable {
    case remote
    case cache
    case bundled
}

struct PresetLoadResult {
    let response: PresetListResponse
    let source: PresetLoadSource
}

struct WeatherData: Codable {
    let temperatureC: Double
    let feelsLikeC: Double
    let condition: String
    let precipitationProbability: Double
    let windSpeedKph: Double?

    static let demo = WeatherData(
        temperatureC: 16,
        feelsLikeC: 15,
        condition: "partly_cloudy",
        precipitationProbability: 0.2,
        windSpeedKph: 12
    )

    var summary: String {
        "\(Int(temperatureC.rounded()))°C"
    }
}

enum LocalPresetCatalog {
    static let choices: [OccasionPreset] = [
        preset(
            id: "first-date",
            name: "First date",
            aliases: ["第一次约会", "首次约会", "初次见面的约会"],
            description: "Clean, approachable, and low-pressure.",
            formality: .smartCasual,
            allowed: [.casual, .smartCasual],
            keywords: ["Clean", "Approachable", "Natural"]
        ),
        preset(
            id: "club-speech",
            name: "Club speech",
            aliases: ["社团汇报", "社团分享", "社团路演"],
            description: "Credible and professional without feeling too formal.",
            formality: .business,
            allowed: [.smartCasual, .business],
            keywords: ["Credible", "Clear", "Polished"]
        ),
        preset(
            id: "friends-dinner",
            name: "Friends dinner",
            aliases: ["朋友吃饭", "同学聚餐", "朋友生日聚餐"],
            description: "Relaxed, friendly, and tidy.",
            formality: .casual,
            allowed: [.casual, .smartCasual],
            keywords: ["Relaxed", "Friendly", "Natural"]
        ),
        preset(
            id: "internship-interview",
            name: "Internship interview",
            aliases: ["面试", "实习面试", "工作面试"],
            description: "Clear and reliable without being flashy.",
            formality: .business,
            allowed: [.smartCasual, .business],
            keywords: ["Reliable", "Clear", "Professional"]
        )
    ]

    static let familyDinner = preset(
        id: "generated-family-dinner",
        name: "Family dinner",
        aliases: ["第一次去女朋友家吃饭", "第一次去对象家吃饭", "见家长前聚餐"],
        description: "Naturally tidy without looking like a formal interview.",
        formality: .smartCasual,
        allowed: [.casual, .smartCasual],
        keywords: ["Clean", "Natural", "Polite", "Not overdressed"]
    )

    static let nightOut = preset(
        id: "night-out",
        name: "Night out",
        aliases: [
            "去夜店",
            "夜店",
            "夜生活",
            "派对",
            "酒吧",
            "clubbing",
            "night out",
            "nightclub",
            "club night"
        ],
        description: "Relaxed and expressive, never like a business meeting.",
        formality: .casual,
        allowed: [.casual, .smartCasual],
        keywords: ["Nightlife", "Self-expression", "Relaxed", "Distinctive"],
        source: "bundled"
    )

    static let all = choices + [
        familyDinner,
        nightOut,
        preset(
            id: "anniversary-date",
            name: "Anniversary date",
            aliases: ["纪念日", "周年约会", "结婚纪念日"],
            description: "A polished step up from an everyday outfit.",
            formality: .smartCasual,
            allowed: [.smartCasual, .business],
            keywords: ["Polished", "Warm", "Occasion"]
        ),
        preset(
            id: "salon-performance",
            name: "Salon performance",
            aliases: ["沙龙", "演奏会", "节目演出", "小型演出"],
            description: "Stage presence with freedom to move.",
            formality: .smartCasual,
            allowed: [.casual, .smartCasual, .business],
            keywords: ["Layered", "Mobile", "Expressive"]
        )
    ]

    static func resolve(
        _ query: String,
        formalityHint: FormalityBand? = nil
    ) -> OccasionResolveResponse? {
        let normalized = normalize(query)
        guard !normalized.isEmpty else {
            return nil
        }

        if normalized.contains(normalize("女朋友家"))
            || normalized.contains(normalize("对象家"))
            || normalized.contains(normalize("见家长"))
            || normalized.contains(normalize("家庭聚餐"))
        {
            return response(query: query, profile: familyDinner, matchType: "generated")
        }

        if let profile = all.first(where: { preset in
            ([preset.name] + preset.aliases).contains { value in
                let normalizedValue = normalize(value)
                return normalized == normalizedValue
                    || normalized.contains(normalizedValue)
                    || normalizedValue.contains(normalized)
            }
        }) {
            return response(query: query, profile: profile, matchType: "exact_preset")
        }

        let target = formalityHint ?? .smartCasual
        let fallback = preset(
            id: "fallback-general-occasion",
            name: "General occasion",
            aliases: [query],
            description: "A clean, natural strategy for an unfamiliar occasion.",
            formality: target,
            allowed: neighboringFormality(for: target),
            keywords: ["Tidy", "Natural", "Approachable"]
        )
        return response(query: query, profile: fallback, matchType: "fallback")
    }

    private static func response(
        query: String,
        profile: OccasionPreset,
        matchType: String
    ) -> OccasionResolveResponse {
        OccasionResolveResponse(
            query: query,
            profile: profile,
            matchType: matchType,
            confidence: matchType == "fallback" ? 0.35 : 1,
            cached: matchType != "fallback",
            alternatives: all.filter { $0.id != profile.id && $0.id != familyDinner.id }.prefix(3)
                .map { $0 },
            warning: matchType == "fallback"
                ? "No clear match was found. Local rules are being used."
                : nil,
            requestID: nil
        )
    }

    private static func neighboringFormality(
        for band: FormalityBand
    ) -> [FormalityBand] {
        switch band {
        case .casual: [.casual, .smartCasual]
        case .smartCasual: [.casual, .smartCasual, .business]
        case .business: [.smartCasual, .business, .formal]
        case .formal: [.business, .formal]
        }
    }

    private static func normalize(_ value: String) -> String {
        String(
            value
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
                .filter { $0.isLetter || $0.isNumber }
        )
    }

    private static func preset(
        id: String,
        name: String,
        aliases: [String],
        description: String,
        formality: FormalityBand,
        allowed: [FormalityBand],
        keywords: [String],
        source: String = "precomputed"
    ) -> OccasionPreset {
        OccasionPreset(
            id: id,
            name: name,
            aliases: aliases,
            description: description,
            targetFormality: formality,
            allowedFormality: allowed,
            requiredSlots: [.top, .bottom, .shoes],
            styleKeywords: keywords,
            avoidRules: ["Avoid excessive formality", "Avoid overly complex color and pattern combinations"],
            explanationGuidelines: ["Explain formality", "Explain color relationships", "Explain occasion fit"],
            source: source,
            version: 1,
            generatedAt: nil
        )
    }
}
