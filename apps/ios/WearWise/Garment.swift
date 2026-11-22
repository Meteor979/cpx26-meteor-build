import Foundation

enum GarmentSlot: String, CaseIterable, Codable, Identifiable, Hashable {
    case top
    case bottom
    case shoes
    case outerwear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .shoes: "Shoes"
        case .outerwear: "Outerwear"
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
        case .manual: "Manual entry"
        case .aiSuggestion: "AI suggestion, confirmed"
        case .localMock: "Local sample"
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
        colors.isEmpty ? "Color not set" : colors.joined(separator: ", ")
    }

    var formalityLabel: String {
        "Formality \(formalityScore)/5"
    }
}
