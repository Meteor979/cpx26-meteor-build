import Foundation

protocol RecommendationServiceProtocol {
    func recommend(
        context: RecommendationContext,
        garments: [Garment]
    ) async throws -> RecommendationResponse

    func revise(
        context: RecommendationContext,
        currentOutfit: Outfit,
        replacement: Garment,
        garments: [Garment]
    ) async throws -> OutfitRevisionResponse
}

final class RecommendationService: RecommendationServiceProtocol {
    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func recommend(
        context: RecommendationContext,
        garments: [Garment]
    ) async throws -> RecommendationResponse {
        let request = RecommendationRequest(
            requestID: requestID(),
            presetID: context.presetID,
            occasion: context.occasion,
            weather: context.weather,
            formality: context.formality,
            garments: garments.map(\.recommendationGarment)
        )

        do {
            let data = try await api.createRecommendations(request)
            let response = try JSONCoding.decoder.decode(
                RecommendationResponse.self,
                from: data
            )
            if !response.outfits.isEmpty {
                return response
            }
        } catch let error as APIError where error.statusCode == 422 {
            throw error
        } catch {
            // Local rules keep the prototype usable until the API is deployed.
        }

        return LocalRecommendationEngine.recommend(
            context: context,
            garments: garments
        )
    }

    func revise(
        context: RecommendationContext,
        currentOutfit: Outfit,
        replacement: Garment,
        garments: [Garment]
    ) async throws -> OutfitRevisionResponse {
        let request = OutfitRevisionRequest(
            requestID: requestID(),
            presetID: context.presetID,
            occasion: context.occasion,
            weather: context.weather,
            formality: context.formality,
            garments: garments.map(\.recommendationGarment),
            baseItemIDs: currentOutfit.itemIDs,
            replacementItemID: replacement.id.uuidString.lowercased()
        )

        do {
            let data = try await api.reviseOutfit(request)
            return try JSONCoding.decoder.decode(
                OutfitRevisionResponse.self,
                from: data
            )
        } catch let error as APIError where error.statusCode == 422 {
            throw error
        } catch {
            return LocalRecommendationEngine.revise(
                currentOutfit: currentOutfit,
                replacement: replacement,
                garments: garments
            )
        }
    }

    private func requestID() -> String {
        "ios-\(UUID().uuidString.lowercased())"
    }
}

extension Garment {
    var recommendationGarment: RecommendationGarment {
        RecommendationGarment(
            id: id.uuidString.lowercased(),
            brand: nil,
            productName: name,
            slot: slot,
            category: category.isEmpty ? slot.rawValue : category,
            colors: colors.isEmpty ? ["未标注"] : colors,
            pattern: pattern.isEmpty ? nil : pattern,
            fit: fit.isEmpty ? nil : fit,
            material: material.isEmpty ? nil : material,
            formalityScore: formalityScore,
            warmthScore: warmthScore,
            userConfirmed: userConfirmed
        )
    }

    var formalityBand: FormalityBand {
        switch formalityScore {
        case ...2: .casual
        case 3: .smartCasual
        case 4: .business
        default: .formal
        }
    }
}

enum LocalRecommendationEngine {
    static func recommend(
        context: RecommendationContext,
        garments: [Garment]
    ) -> RecommendationResponse {
        let grouped = Dictionary(grouping: garments, by: \.slot)
        let tops = grouped[.top, default: []]
        let bottoms = grouped[.bottom, default: []]
        let shoes = grouped[.shoes, default: []]
        let outerwear: [Garment?] = [nil]
            + grouped[.outerwear, default: []].map { Optional($0) }

        var candidates: [Outfit] = []
        for top in tops {
            for bottom in bottoms {
                for shoe in shoes {
                    for outer in outerwear {
                        let items = [top, bottom, shoe] + (outer.map { [$0] } ?? [])
                        candidates.append(
                            makeOutfit(
                                items: items,
                                target: context.formality,
                                index: candidates.count
                            )
                        )
                    }
                }
            }
        }

        candidates.sort {
            let left = $0.score ?? 0
            let right = $1.score ?? 0
            if left == right {
                return $0.id < $1.id
            }
            return left > right
        }
        let distinctCount = candidates.count
        var selected = Array(candidates.prefix(3))
        if selected.count < 3, !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty {
            let baseItems = [tops[0], bottoms[0], shoes[0]]
            while selected.count < 3 {
                selected.append(
                    makeOutfit(
                        items: baseItems,
                        target: context.formality,
                        index: selected.count,
                        isFallbackVariant: true
                    )
                )
            }
        }
        let reason = distinctCount >= 3
            ? "three_available"
            : "fallback_degraded"
        let warning = distinctCount < 3
            ? "当前衣柜组合有限，备用方案会复用同一组衣物照片。"
            : nil

        return RecommendationResponse(
            outfits: selected,
            requestedCount: 3,
            resultCountReason: reason,
            fallbackUsed: true,
            warning: warning,
            provider: "ios_local_rules",
            generatedAt: nowISO8601(),
            requestID: "local-\(UUID().uuidString.lowercased())"
        )
    }

    static func revise(
        currentOutfit: Outfit,
        replacement: Garment,
        garments: [Garment]
    ) -> OutfitRevisionResponse {
        let replacementID = replacement.id.uuidString.lowercased()
        let garmentsByID = Dictionary(
            uniqueKeysWithValues: garments.map {
                ($0.id.uuidString.lowercased(), $0)
            }
        )
        let updatedIDs = currentOutfit.itemIDs.map { existingID in
            guard let existingGarment = garmentsByID[existingID] else {
                return existingID
            }
            return existingGarment.slot == replacement.slot
                ? replacementID
                : existingID
        }
        let revised = Outfit(
            id: "\(currentOutfit.id)-revised-\(replacement.id.uuidString.prefix(6).lowercased())",
            itemIDs: updatedIDs,
            title: "已替换\(replacement.name)",
            reasons: [
                "\(replacement.name)已替换同槽位衣物，其他单品保持不变。",
                "当前结果由本地规则生成，可继续调整或确认保存。"
            ],
            tradeoffs: currentOutfit.tradeoffs + ["手动替换后请再次确认整体风格。"],
            source: .manual,
            score: currentOutfit.score
        )
        return OutfitRevisionResponse(
            outfit: revised,
            fallbackUsed: true,
            warning: "后端替换接口不可用，已使用本地替换。",
            provider: "ios_local_rules",
            generatedAt: nowISO8601(),
            requestID: "local-\(UUID().uuidString.lowercased())"
        )
    }

    private static func makeOutfit(
        items: [Garment],
        target: FormalityBand,
        index: Int,
        isFallbackVariant: Bool = false
    ) -> Outfit {
        let average = Double(items.map(\.formalityScore).reduce(0, +))
            / Double(max(1, items.count))
        let targetScore = Double(target.scoreRange.lowerBound)
        let score = max(0, 1 - abs(average - targetScore) / 4)
        let titles = ["清晰而自然", "温和而有层次", "更利落的选择"]
        let title = titles[index % titles.count]
        let top = items.first { $0.slot == .top }
        let bottom = items.first { $0.slot == .bottom }
        let colorReason: String
        if let top, let bottom {
            colorReason = "\(top.colorLabel)与\(bottom.colorLabel)形成清楚的主次关系。"
        } else {
            colorReason = "上下装颜色关系清楚，整体容易辨认。"
        }
        let formalReason = "正式度接近\(target.label)，适合当前场合。"
        let names = items.map(\.name).joined(separator: "、")
        var reasons = [
            colorReason,
            formalReason,
            "\(names)均来自本地照片衣柜。"
        ]
        var tradeoffs = ["当前为本地规则结果，未经过真实 AI 生成解释。"]
        if isFallbackVariant {
            reasons.append("当前为备用变体，复用同一组衣物照片。")
            tradeoffs.append("如需更多不同组合，请继续添加同类衣物。")
        }

        return Outfit(
            id: "local-\(index + 1)-\(items.map { $0.id.uuidString.prefix(4) }.joined(separator: "-").lowercased())",
            itemIDs: items.map { $0.id.uuidString.lowercased() },
            title: title,
            reasons: reasons,
            tradeoffs: tradeoffs,
            source: .mock,
            score: score
        )
    }

    private static func nowISO8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
