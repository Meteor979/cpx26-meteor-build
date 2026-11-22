import Foundation

enum FormalityBand: String, Codable, CaseIterable, Identifiable, Hashable {
    case casual
    case smartCasual = "smart_casual"
    case business
    case formal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: "休闲"
        case .smartCasual: "智能休闲"
        case .business: "商务"
        case .formal: "正式"
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
            name: "初次约会",
            aliases: ["第一次约会", "首次约会", "初次见面的约会"],
            description: "保持整洁、亲近和低压迫感。",
            formality: .smartCasual,
            allowed: [.casual, .smartCasual],
            keywords: ["干净", "亲近", "自然"]
        ),
        preset(
            id: "club-speech",
            name: "社团演讲",
            aliases: ["社团汇报", "社团分享", "社团路演"],
            description: "专业可信，但不过度正式。",
            formality: .business,
            allowed: [.smartCasual, .business],
            keywords: ["可信", "清晰", "利落"]
        ),
        preset(
            id: "friends-dinner",
            name: "朋友聚餐",
            aliases: ["朋友吃饭", "同学聚餐", "朋友生日聚餐"],
            description: "轻松、友好，保持整洁。",
            formality: .casual,
            allowed: [.casual, .smartCasual],
            keywords: ["轻松", "友好", "自然"]
        ),
        preset(
            id: "internship-interview",
            name: "实习面试",
            aliases: ["面试", "实习面试", "工作面试"],
            description: "清楚、可靠，避免过度张扬。",
            formality: .business,
            allowed: [.smartCasual, .business],
            keywords: ["可靠", "清楚", "专业"]
        )
    ]

    static let familyDinner = preset(
        id: "generated-family-dinner",
        name: "第一次家庭聚餐",
        aliases: ["第一次去女朋友家吃饭", "第一次去对象家吃饭", "见家长前聚餐"],
        description: "自然整洁，避免像正式面试。",
        formality: .smartCasual,
        allowed: [.casual, .smartCasual],
        keywords: ["干净", "自然", "有礼貌", "不过度正式"]
    )

    static let nightOut = preset(
        id: "night-out",
        name: "夜店",
        aliases: ["去夜店", "夜店", "夜生活", "派对", "酒吧", "clubbing"],
        description: "轻松、有个人表达，避免像商务会面。",
        formality: .casual,
        allowed: [.casual, .smartCasual],
        keywords: ["夜间社交", "个人表达", "轻松", "有辨识度"],
        source: "bundled"
    )

    static let all = choices + [
        familyDinner,
        nightOut,
        preset(
            id: "anniversary-date",
            name: "纪念日约会",
            aliases: ["纪念日", "周年约会", "结婚纪念日"],
            description: "在日常基础上增加一点仪式感。",
            formality: .smartCasual,
            allowed: [.smartCasual, .business],
            keywords: ["精致", "温和", "仪式感"]
        ),
        preset(
            id: "salon-performance",
            name: "沙龙表演",
            aliases: ["沙龙", "演奏会", "节目演出", "小型演出"],
            description: "兼顾舞台辨识度和行动便利。",
            formality: .smartCasual,
            allowed: [.casual, .smartCasual, .business],
            keywords: ["层次", "便于行动", "个人表达"]
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
            name: "通用场合策略",
            aliases: [query],
            description: "使用整洁自然的通用策略。",
            formality: target,
            allowed: neighboringFormality(for: target),
            keywords: ["整洁", "自然", "可接近"]
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
                ? "未找到明确匹配，已使用本地通用策略。"
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
            avoidRules: ["避免过度正式", "避免颜色和图案过度复杂"],
            explanationGuidelines: ["解释正式程度", "解释颜色关系", "解释场合适配"],
            source: source,
            version: 1,
            generatedAt: nil
        )
    }
}
