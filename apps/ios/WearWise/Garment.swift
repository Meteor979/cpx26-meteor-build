import Foundation

enum GarmentSlot: String, CaseIterable, Codable, Identifiable, Hashable {
    case top
    case bottom
    case shoes
    case outerwear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "上装"
        case .bottom: "下装"
        case .shoes: "鞋"
        case .outerwear: "外套"
        }
    }

    var systemImage: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "rectangle.split.2x1"
        case .shoes: "shoe"
        case .outerwear: "jacket"
        }
    }

    var displayOrder: Int {
        switch self {
        case .top: 0
        case .bottom: 1
        case .shoes: 2
        case .outerwear: 3
        }
    }
}

enum GarmentSource: String, Codable {
    case manual
    case aiSuggestion
    case localMock

    var label: String {
        switch self {
        case .manual: "手动录入"
        case .aiSuggestion: "AI 建议，已确认"
        case .localMock: "本地样例"
        }
    }
}

struct Garment: Identifiable, Codable, Equatable {
    let id: UUID
    let localPhotoPath: String
    let thumbnailPath: String
    let capturedAt: Date
    let name: String
    let slot: GarmentSlot
    let category: String
    let colors: [String]
    let pattern: String
    let fit: String
    let material: String
    let formalityScore: Int
    let warmthScore: Int
    let userConfirmed: Bool
    let source: GarmentSource

    enum CodingKeys: String, CodingKey {
        case id = "garment_id"
        case localPhotoPath = "local_photo_path"
        case thumbnailPath = "thumbnail_path"
        case capturedAt = "captured_at"
        case name
        case slot
        case category
        case colors
        case pattern
        case fit
        case material
        case formalityScore = "formality_score"
        case warmthScore = "warmth_score"
        case userConfirmed = "user_confirmed"
        case source
    }

    var colorLabel: String {
        colors.isEmpty ? "颜色未填写" : colors.joined(separator: "、")
    }

    var formalityLabel: String {
        "正式度 \(formalityScore)/5"
    }
}
