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
            if response.outfits.count >= 3,
                response.outfits.allSatisfy(hasEnglishCopy)
            {
                return response
            }
        } catch let error as APIError
            where error.statusCode == 422 || error.isTimeout
        {
            throw error
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
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
            if Task.isCancelled {
                throw CancellationError()
            }
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

    private func hasEnglishCopy(_ outfit: Outfit) -> Bool {
        let visibleCopy =
            ([outfit.title] + outfit.reasons + outfit.tradeoffs)
            .joined(separator: " ")
        return visibleCopy.unicodeScalars.allSatisfy {
            !(0x4E00...0x9FFF).contains($0.value)
        }
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
            colors: colors.isEmpty ? ["Not specified"] : colors,
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
            ? "The wardrobe has limited combinations. Fallback options reuse the same clothing photos."
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
            title: "Replaced \(replacement.name)",
            reasons: [
                "\(replacement.name) replaced the item in the same slot. Other items are unchanged.",
                "This result was built with local rules and is ready for another review."
            ],
            tradeoffs: [
                "This manual replacement uses local rules.",
                "Review the overall style before confirming."
            ],
            source: .manual,
            score: currentOutfit.score
        )
        return OutfitRevisionResponse(
            outfit: revised,
            fallbackUsed: true,
            warning: "The backend revision was unavailable. A local replacement was used.",
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
        let titles = [
            "Clear and natural",
            "Warm and layered",
            "Sharper and more expressive"
        ]
        let title = titles[index % titles.count]
        let top = items.first { $0.slot == .top }
        let bottom = items.first { $0.slot == .bottom }
        let colorReason: String
        if let top, let bottom {
            colorReason =
                "\(top.colorLabel) and \(bottom.colorLabel) create a clear visual hierarchy."
        } else {
            colorReason = "The top and bottom have a clear, easy-to-read color relationship."
        }
        let formalReason =
            "The formality level is close to \(target.label) and suits this occasion."
        let names = items.map(\.name).joined(separator: "、")
        var reasons = [
            colorReason,
            formalReason,
            "Every item in \(names) comes from the local photo wardrobe."
        ]
        var tradeoffs = [
            "This result uses local rules rather than generated AI explanations."
        ]
        if isFallbackVariant {
            reasons.append(
                "This fallback variation reuses the same clothing photos."
            )
            tradeoffs.append(
                "Add more items in the same slots for more distinct combinations."
            )
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
