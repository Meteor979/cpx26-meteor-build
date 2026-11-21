import XCTest
@testable import WearWise

final class OccasionRecommendationTests: XCTestCase {
    @MainActor
    func testEmptyOccasionCannotResolve() async {
        let viewModel = OccasionRecommendationViewModel()
        viewModel.query = "   "

        XCTAssertFalse(viewModel.canResolve)
        await viewModel.resolveOccasion()
        XCTAssertEqual(viewModel.errorMessage, "请先输入场合。")
    }

    func testLocalPresetMatchesWithoutNetwork() async throws {
        let service = OccasionService(api: StubAPIClient())
        let result = try await service.resolve(
            query: "社团演讲",
            formalityHint: nil
        )

        XCTAssertEqual(result.response.profile.id, "club-speech")
        XCTAssertEqual(result.sourceLabel, "本地预设")
    }

    func testOccasionResponseDecodesSnakeCase() throws {
        let data = Data(
            """
            {
              "query": "第一次约会",
              "profile": {
                "id": "first-date",
                "name": "初次约会",
                "aliases": ["第一次约会"],
                "description": "整洁自然",
                "target_formality": "smart_casual",
                "allowed_formality": ["casual", "smart_casual"],
                "required_slots": ["top", "bottom", "shoes"],
                "style_keywords": ["自然"],
                "avoid_rules": [],
                "explanation_guidelines": [],
                "source": "precomputed",
                "version": 1,
                "generated_at": "2026-11-20T10:00:00+08:00"
              },
              "match_type": "exact_preset",
              "confidence": 1.0,
              "cached": true,
              "alternatives": [],
              "warning": null,
              "request_id": "req-1"
            }
            """.utf8
        )

        let response = try JSONCoding.decoder.decode(
            OccasionResolveResponse.self,
            from: data
        )

        XCTAssertEqual(response.profile.targetFormality, .smartCasual)
        XCTAssertEqual(response.requestID, "req-1")
    }

    func testAcronymFieldsUseSnakeCase() throws {
        let request = OccasionResolveRequest(
            requestID: "req-1",
            query: "第一次约会",
            locale: "zh-CN",
            formalityHint: nil
        )
        let data = try JSONCoding.encoder.encode(request)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["request_id"] as? String, "req-1")
        XCTAssertNil(object["requestId"])

        let outfitData = Data(
            """
            {
              "id": "outfit-a",
              "item_ids": ["a", "b", "c"],
              "title": "测试搭配",
              "reasons": ["理由"],
              "tradeoffs": [],
              "source": "mock"
            }
            """.utf8
        )
        let outfit = try JSONCoding.decoder.decode(Outfit.self, from: outfitData)
        XCTAssertEqual(outfit.itemIDs, ["a", "b", "c"])
    }

    func testNetworkFailureUsesLocalFallback() async throws {
        let api = StubAPIClient(
            resolveError: APIError.network("offline")
        )
        let service = OccasionService(api: api)
        let result = try await service.resolve(
            query: "一个没有本地预设的场合",
            formalityHint: .business
        )

        XCTAssertEqual(result.response.matchType, "fallback")
        XCTAssertEqual(result.response.profile.targetFormality, .business)
        XCTAssertEqual(result.sourceLabel, "本地备用")
    }

    func testValidation422IsNotHiddenByFallback() async {
        let api = StubAPIClient(
            resolveError: APIError.server(
                status: 422,
                code: "VALIDATION_ERROR",
                message: "请求字段不符合接口契约。"
            )
        )
        let service = OccasionService(api: api)

        do {
            _ = try await service.resolve(
                query: "未知场合",
                formalityHint: nil
            )
            XCTFail("Expected validation error")
        } catch let error as APIError {
            XCTAssertEqual(error.statusCode, 422)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotModifiedUsesCachedPresets() async throws {
        let suiteName = "WearWiseTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let cached = PresetListResponse(
            version: 1,
            cached: true,
            generatedAt: nil,
            presets: LocalPresetCatalog.choices
        )
        defaults.set(try JSONCoding.encoder.encode(cached), forKey: "wearwise.presets.response")
        defaults.set(1, forKey: "wearwise.presets.version")

        let service = PresetService(
            api: StubAPIClient(presetError: APIError.notModified),
            defaults: defaults
        )
        let result = await service.loadPresets()

        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.response.presets.first?.id, "first-date")
    }

    @MainActor
    func testRemoteIDsMapToLocalGarments() {
        let garments = makeCoreGarments()
        let ids = garments.map { $0.id.uuidString.lowercased() }
        let outfit = Outfit(
            id: "remote-outfit",
            itemIDs: ids,
            title: "远程方案",
            reasons: ["测试"],
            tradeoffs: [],
            source: .remoteAPI,
            score: 0.9
        )

        let resolved = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments
        )

        XCTAssertEqual(resolved.items.count, 3)
        XCTAssertTrue(resolved.items.allSatisfy { $0.garment != nil })
        XCTAssertEqual(resolved.sourceLabel, "后端结果")
    }

    func testLimitedWardrobeCreatesThreeExplicitVariants() {
        let response = LocalRecommendationEngine.recommend(
            context: context(),
            garments: makeCoreGarments()
        )

        XCTAssertEqual(response.outfits.count, 3)
        XCTAssertEqual(response.resultCountReason, "fallback_degraded")
        XCTAssertNotNil(response.warning)
        XCTAssertEqual(Set(response.outfits.map(\.itemIDs)).count, 1)
    }

    func testLocalRevisionUpdatesOnlyMatchingSlot() {
        let garments = makeCoreGarments()
        let replacement = Garment(
            id: UUID(),
            localPhotoPath: "replacement.jpg",
            thumbnailPath: "replacement-thumb.jpg",
            capturedAt: Date(),
            name: "棕色乐福鞋",
            slot: .shoes,
            category: "loafers",
            colors: ["棕色"],
            pattern: "纯色",
            fit: "常规",
            material: "皮革",
            formalityScore: 3,
            warmthScore: 2,
            userConfirmed: true,
            source: .manual
        )
        let current = Outfit(
            id: "outfit-a",
            itemIDs: garments.map { $0.id.uuidString.lowercased() },
            title: "当前方案",
            reasons: ["测试"],
            tradeoffs: [],
            source: .mock,
            score: 0.8
        )

        let revised = LocalRecommendationEngine.revise(
            currentOutfit: current,
            replacement: replacement,
            garments: garments + [replacement]
        )

        XCTAssertTrue(
            revised.outfit.itemIDs.contains(
                replacement.id.uuidString.lowercased()
            )
        )
        XCTAssertEqual(
            revised.outfit.itemIDs.filter {
                $0 == garments[0].id.uuidString.lowercased()
                    || $0 == garments[1].id.uuidString.lowercased()
            }.count,
            2
        )
        XCTAssertEqual(revised.outfit.source, .manual)
    }

    @MainActor
    func testSavedPlanSurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let plan = SavedPlan(
            outfitID: "outfit-a",
            outfitTitle: "清晰而自然",
            itemIDs: ["top", "bottom", "shoes"],
            occasion: "第一次约会",
            formality: .smartCasual,
            weather: .demo,
            recommendationSource: "本地样例",
            savedAt: Date()
        )
        let store = SavedPlanStore(rootDirectory: directory)
        try store.save(plan)

        let reloaded = SavedPlanStore(rootDirectory: directory)

        XCTAssertEqual(reloaded.plans.count, 1)
        XCTAssertEqual(reloaded.latest?.occasion, "第一次约会")
        XCTAssertEqual(reloaded.latest?.itemIDs, plan.itemIDs)
    }

    private func context() -> RecommendationContext {
        RecommendationContext(
            occasion: "第一次约会",
            presetID: "first-date",
            formality: .smartCasual,
            weather: .demo
        )
    }

    private func makeCoreGarments() -> [Garment] {
        [
            testGarment(
                name: "浅蓝衬衫",
                slot: .top,
                category: "shirt",
                colors: ["浅蓝"],
                formality: 3
            ),
            testGarment(
                name: "深蓝牛仔裤",
                slot: .bottom,
                category: "jeans",
                colors: ["深蓝"],
                formality: 2
            ),
            testGarment(
                name: "白色运动鞋",
                slot: .shoes,
                category: "sneakers",
                colors: ["白色"],
                formality: 2
            )
        ]
    }

    private func testGarment(
        name: String,
        slot: GarmentSlot,
        category: String,
        colors: [String],
        formality: Int
    ) -> Garment {
        Garment(
            id: UUID(),
            localPhotoPath: "\(UUID().uuidString).jpg",
            thumbnailPath: "\(UUID().uuidString)-thumb.jpg",
            capturedAt: Date(),
            name: name,
            slot: slot,
            category: category,
            colors: colors,
            pattern: "纯色",
            fit: "常规",
            material: "棉",
            formalityScore: formality,
            warmthScore: 2,
            userConfirmed: true,
            source: .manual
        )
    }
}

private final class StubAPIClient: APIClientProtocol {
    var presetError: Error?
    var resolveError: Error?
    var recommendationError: Error?
    var revisionError: Error?

    init(
        presetError: Error? = nil,
        resolveError: Error? = nil,
        recommendationError: Error? = nil,
        revisionError: Error? = nil
    ) {
        self.presetError = presetError
        self.resolveError = resolveError
        self.recommendationError = recommendationError
        self.revisionError = revisionError
    }

    func fetchPresets(version: Int?) async throws -> Data {
        if let presetError {
            throw presetError
        }
        return try JSONCoding.encoder.encode(
            PresetListResponse(
                version: 1,
                cached: false,
                generatedAt: nil,
                presets: LocalPresetCatalog.choices
            )
        )
    }

    func resolveOccasion(_ request: OccasionResolveRequest) async throws -> Data {
        if let resolveError {
            throw resolveError
        }
        throw APIError.server(
            status: 503,
            code: "PROVIDER_UNAVAILABLE",
            message: "服务暂不可用"
        )
    }

    func createRecommendations(_ request: RecommendationRequest) async throws -> Data {
        if let recommendationError {
            throw recommendationError
        }
        throw APIError.server(status: 503, code: nil, message: "服务暂不可用")
    }

    func reviseOutfit(_ request: OutfitRevisionRequest) async throws -> Data {
        if let revisionError {
            throw revisionError
        }
        throw APIError.server(status: 503, code: nil, message: "服务暂不可用")
    }
}
