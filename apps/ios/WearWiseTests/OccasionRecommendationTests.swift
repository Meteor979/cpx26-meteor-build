import XCTest
@testable import WearWise

final class OccasionRecommendationTests: XCTestCase {
    @MainActor
    func testEmptyOccasionCannotResolve() async {
        let viewModel = OccasionRecommendationViewModel()
        viewModel.query = "   "
        let canResolve = viewModel.canResolve

        XCTAssertFalse(canResolve)
        await viewModel.resolveOccasion()
        let errorMessage = viewModel.errorMessage
        XCTAssertEqual(errorMessage, "Enter an occasion first.")
    }

    @MainActor
    func testOccasionLoadingStateIsVisible() async {
        let viewModel = OccasionRecommendationViewModel(
            occasionService: DelayedOccasionService()
        )
        viewModel.query = "Dinner with family"

        let task = Task {
            await viewModel.resolveOccasion()
        }
        try? await Task.sleep(nanoseconds: 30_000_000)
        let isResolving = viewModel.isResolving
        let message = viewModel.operationMessage

        XCTAssertTrue(isResolving)
        XCTAssertEqual(message, "Resolving your occasion...")
        task.cancel()
        await task.value
    }

    func testLocalPresetMatchesWithoutNetwork() async throws {
        let service = OccasionService(api: StubAPIClient())
        let result = try await service.resolve(
            query: "社团演讲",
            formalityHint: nil
        )

        XCTAssertEqual(result.response.profile.id, "club-speech")
        XCTAssertEqual(result.sourceLabel, "Local rules")
    }

    @MainActor
    func testChangingQueryClearsPreviousBusinessFormality() async {
        let viewModel = OccasionRecommendationViewModel(
            occasionService: OccasionService(api: StubAPIClient())
        )
        viewModel.query = "社团演讲"
        await viewModel.resolveOccasion()
        let clubFormality = viewModel.formality

        XCTAssertEqual(clubFormality, .business)

        viewModel.query = "去夜店"
        viewModel.queryDidChange()
        let profile = viewModel.profile
        let resolvedQuery = viewModel.resolvedQuery
        let source = viewModel.resolutionSource
        let formality = viewModel.formality

        XCTAssertNil(profile)
        XCTAssertEqual(resolvedQuery, "")
        XCTAssertEqual(source, "")
        XCTAssertEqual(formality, .smartCasual)
    }

    @MainActor
    func testAdjustingFormalityMarksContextChanged() async {
        let viewModel = OccasionRecommendationViewModel(
            occasionService: OccasionService(api: StubAPIClient())
        )
        viewModel.query = "Club speech"
        await viewModel.resolveOccasion()

        viewModel.adjustFormality(.casual)
        let changed = viewModel.contextChanged
        let formality = viewModel.formality

        XCTAssertTrue(changed)
        XCTAssertEqual(formality, .casual)
    }

    @MainActor
    func testUsingPresetAppliesItsFormality() {
        let viewModel = OccasionRecommendationViewModel()
        let preset = LocalPresetCatalog.choices.first {
            $0.id == "club-speech"
        }!

        viewModel.usePreset(preset)
        viewModel.queryDidChange()
        let query = viewModel.query
        let formality = viewModel.formality

        XCTAssertEqual(query, "Club speech")
        XCTAssertEqual(formality, .business)
    }

    func testNightOutOfflineFallbackIsCasual() async throws {
        let service = OccasionService(
            api: StubAPIClient(resolveError: APIError.network("offline"))
        )
        let result = try await service.resolve(
            query: "去夜店",
            formalityHint: .business
        )

        XCTAssertEqual(result.response.profile.id, "night-out")
        XCTAssertEqual(result.response.profile.targetFormality, .casual)
    }

    func testNightOutRejectsIncorrectBusinessBackendResult() async throws {
        let businessResponse = OccasionResolveResponse(
            query: "night out",
            profile: LocalPresetCatalog.choices.first {
                $0.id == "club-speech"
            }!,
            matchType: "fallback",
            confidence: 0.35,
            cached: false,
            alternatives: [],
            warning: "Incorrect fallback",
            requestID: "bad-night-out"
        )
        let data = try JSONCoding.encoder.encode(businessResponse)
        let result = try await OccasionService(
            api: StubAPIClient(resolveData: data)
        ).resolve(
            query: "night out",
            formalityHint: .business
        )

        XCTAssertEqual(result.response.profile.id, "night-out")
        XCTAssertEqual(result.response.profile.targetFormality, .casual)
        XCTAssertEqual(result.sourceLabel, "Fallback result")
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
        XCTAssertEqual(result.sourceLabel, "Fallback result")
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

    func testRecommendationNetworkFailureUsesLocalFallback() async throws {
        let service = RecommendationService(
            api: StubAPIClient(
                recommendationError: APIError.network("offline")
            )
        )
        let response = try await service.recommend(
            context: context(),
            garments: makeCoreGarments()
        )

        XCTAssertEqual(response.outfits.count, 3)
        XCTAssertTrue(response.fallbackUsed)
        XCTAssertEqual(response.provider, "ios_local_rules")
    }

    func testAIRecommendationResponseDecodes() throws {
        let data = Data(
            """
            {
              "outfits": [{
                "id": "ai-a",
                "item_ids": ["top-id", "bottom-id", "shoes-id"],
                "title": "Clean and confident",
                "reasons": ["The formality suits the occasion."],
                "tradeoffs": ["The look is slightly formal."],
                "source": "remote_api",
                "score": 0.91
              }],
              "requested_count": 1,
              "result_count_reason": "limited_candidates",
              "fallback_used": false,
              "warning": null,
              "provider": "openai-provider",
              "generated_at": "2026-11-22T10:00:00Z",
              "request_id": "req-ai-1"
            }
            """.utf8
        )

        let response = try JSONCoding.decoder.decode(
            RecommendationResponse.self,
            from: data
        )

        XCTAssertEqual(response.outfits.first?.title, "Clean and confident")
        XCTAssertEqual(response.provider, "openai-provider")
        XCTAssertFalse(response.fallbackUsed)
    }

    func testNonEnglishAIResponseFallsBackToEnglishLocalRules() async throws {
        let garments = makeCoreGarments()
        let ids = garments.map { $0.id.uuidString.lowercased() }
        let chineseResponse = RecommendationResponse(
            outfits: (0..<3).map { index in
                Outfit(
                    id: "chinese-\(index)",
                    itemIDs: ids,
                    title: "中文标题",
                    reasons: ["中文理由"],
                    tradeoffs: ["中文取舍"],
                    source: .remoteAPI,
                    score: 0.8
                )
            },
            requestedCount: 3,
            resultCountReason: "three_available",
            fallbackUsed: false,
            warning: nil,
            provider: "test-ai",
            generatedAt: nil,
            requestID: "chinese-ai"
        )
        let data = try JSONCoding.encoder.encode(chineseResponse)
        let response = try await RecommendationService(
            api: StubAPIClient(recommendationData: data)
        ).recommend(
            context: context(),
            garments: garments
        )

        XCTAssertEqual(response.provider, "ios_local_rules")
        XCTAssertTrue(
            response.outfits.allSatisfy {
                !$0.title.contains("中文") && !$0.reasons.joined().contains("中文")
            }
        )
    }

    @MainActor
    func testRecommendationTimeoutKeepsExistingResultsThenLocalContinue() async {
        let garments = makeCoreGarments()
        let success = recommendationResponse(
            garments: garments,
            provider: "openai-provider",
            fallbackUsed: false
        )
        let service = ScriptedRecommendationService(
            results: [
                .success(success),
                .failure(APIError.timeout)
            ]
        )
        let viewModel = OccasionRecommendationViewModel(
            recommendationService: service
        )

        await viewModel.generateRecommendations(garments: garments)
        let initialCount = viewModel.recommendations.count
        await viewModel.generateRecommendations(garments: garments)
        let retainedCount = viewModel.recommendations.count
        let timedOut = viewModel.recommendationTimedOut

        XCTAssertEqual(initialCount, 3)
        XCTAssertEqual(retainedCount, 3)
        XCTAssertTrue(timedOut)

        viewModel.useLocalRecommendations(garments: garments)
        let localCount = viewModel.recommendations.count
        let localSource = viewModel.recommendations.first?.sourceLabel
        XCTAssertEqual(localCount, 3)
        XCTAssertEqual(localSource, "Local rules")
    }

    @MainActor
    func testSourceLabelsUseProviderAndFallbackState() {
        let garments = makeCoreGarments()
        let response = recommendationResponse(
            garments: garments,
            provider: "openai-provider",
            fallbackUsed: false
        )
        let outfit = response.outfits[0]

        let ai = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments,
            provider: "openai-provider",
            fallbackUsed: false
        )
        let rule = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments,
            provider: "rule_engine_mock",
            fallbackUsed: false
        )
        let fallback = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments,
            provider: "openai-provider",
            fallbackUsed: true
        )
        let manual = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments,
            forceManual: true,
            provider: "openai-provider",
            fallbackUsed: false
        )

        XCTAssertEqual(ai.sourceLabel, "AI result")
        XCTAssertEqual(rule.sourceLabel, "Local rules")
        XCTAssertEqual(fallback.sourceLabel, "Fallback result")
        XCTAssertEqual(manual.sourceLabel, "Manual adjustment")
    }

    @MainActor
    func testUnmappedItemKeepsNamedPlaceholder() {
        let garments = makeCoreGarments()
        let outfit = Outfit(
            id: "unmapped",
            itemIDs: [
                garments[0].id.uuidString.lowercased(),
                garments[1].id.uuidString.lowercased(),
                "unknown-item-id"
            ],
            title: "Test outfit",
            reasons: ["Test reason"],
            tradeoffs: [],
            source: .remoteAPI,
            score: 0.5
        )
        let resolved = OccasionRecommendationViewModel.resolveOutfit(
            outfit,
            garments: garments
        )
        let missing = resolved.items.first {
            $0.remoteID == "unknown-item-id"
        }

        XCTAssertEqual(missing?.garment, nil)
        XCTAssertTrue(missing?.displayName.hasPrefix("Unmapped item") == true)
        XCTAssertNotNil(missing?.mappingWarning)
    }

    func testEnglishAIStateLabelsAreStaticAndLocalized() {
        let strings = [
            "Resolving your occasion...",
            "AI is refining the context...",
            "Using local rules...",
            "Building three outfit options...",
            "Comparing formality and weather...",
            "Checking your wardrobe photos...",
            OccasionUICopy.tryAgain,
            OccasionUICopy.useLocalRules,
            OccasionUICopy.contextChanged
        ]

        for value in strings {
            XCTAssertNil(value.range(of: "\\p{Han}", options: .regularExpression))
        }
    }

    func testEndpointSpecificTimeouts() {
        XCTAssertEqual(APIRequestTimeout.presets, 5)
        XCTAssertEqual(APIRequestTimeout.occasionResolution, 15)
        XCTAssertEqual(APIRequestTimeout.recommendations, 20)
        XCTAssertEqual(APIRequestTimeout.outfitRevision, 15)
        XCTAssertEqual(APIRequestTimeout.weatherCurrent, 8)
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

    func testCachedOccasionResolutionShowsCachedResult() async throws {
        let response = OccasionResolveResponse(
            query: "A cached event",
            profile: LocalPresetCatalog.choices[0],
            matchType: "exact_preset",
            confidence: 1,
            cached: true,
            alternatives: [],
            warning: nil,
            requestID: "cached-1"
        )
        let data = try JSONCoding.encoder.encode(response)
        let result = try await OccasionService(
            api: StubAPIClient(resolveData: data)
        ).resolve(
            query: "An unknown cached event",
            formalityHint: nil
        )

        XCTAssertEqual(result.sourceLabel, "Cached result")
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
        XCTAssertEqual(resolved.sourceLabel, "AI result")
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
            reasons: ["Old AI reason that may no longer be valid."],
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
        XCTAssertFalse(
            revised.outfit.reasons.contains(
                "Old AI reason that may no longer be valid."
            )
        )
    }

    func testRevisionTimeoutUsesManualLocalAdjustment() async throws {
        let garments = makeCoreGarments()
        let replacement = Garment(
            id: UUID(),
            localPhotoPath: "replacement.jpg",
            thumbnailPath: "replacement-thumb.jpg",
            capturedAt: Date(),
            name: "Brown loafers",
            slot: .shoes,
            category: "loafers",
            colors: ["Brown"],
            pattern: "Solid",
            fit: "Regular",
            material: "Leather",
            formalityScore: 3,
            warmthScore: 2,
            userConfirmed: true,
            source: .manual
        )
        let current = Outfit(
            id: "current",
            itemIDs: garments.map { $0.id.uuidString.lowercased() },
            title: "AI outfit",
            reasons: ["Old AI reason"],
            tradeoffs: ["Old AI tradeoff"],
            source: .remoteAPI,
            score: 0.9
        )
        let service = RecommendationService(
            api: StubAPIClient(revisionError: APIError.timeout)
        )

        let revised = try await service.revise(
            context: context(),
            currentOutfit: current,
            replacement: replacement,
            garments: garments + [replacement]
        )

        XCTAssertEqual(revised.outfit.source, .manual)
        XCTAssertTrue(revised.outfit.itemIDs.contains(
            replacement.id.uuidString.lowercased()
        ))
        XCTAssertFalse(revised.outfit.reasons.contains("Old AI reason"))
        XCTAssertFalse(revised.outfit.tradeoffs.contains("Old AI tradeoff"))
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
            recommendationSource: "Local rules",
            savedAt: Date()
        )
        let store = SavedPlanStore(rootDirectory: directory)
        try store.save(plan)

        let reloaded = SavedPlanStore(rootDirectory: directory)
        let planCount = reloaded.plans.count
        let latestOccasion = reloaded.latest?.occasion
        let latestItemIDs = reloaded.latest?.itemIDs

        XCTAssertEqual(planCount, 1)
        XCTAssertEqual(latestOccasion, "第一次约会")
        XCTAssertEqual(latestItemIDs, plan.itemIDs)
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

    private func recommendationResponse(
        garments: [Garment],
        provider: String,
        fallbackUsed: Bool
    ) -> RecommendationResponse {
        let ids = garments.map { $0.id.uuidString.lowercased() }
        return RecommendationResponse(
            outfits: (0..<3).map { index in
                Outfit(
                    id: "outfit-\(index)",
                    itemIDs: ids,
                    title: "Outfit \(index + 1)",
                    reasons: ["Occasion-aware reason."],
                    tradeoffs: ["A reasonable tradeoff."],
                    source: fallbackUsed ? .fallback : .remoteAPI,
                    score: 0.9
                )
            },
            requestedCount: 3,
            resultCountReason: "three_available",
            fallbackUsed: fallbackUsed,
            warning: nil,
            provider: provider,
            generatedAt: nil,
            requestID: "req-test"
        )
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
    var resolveData: Data?
    var recommendationError: Error?
    var recommendationData: Data?
    var revisionError: Error?

    init(
        presetError: Error? = nil,
        resolveError: Error? = nil,
        resolveData: Data? = nil,
        recommendationError: Error? = nil,
        recommendationData: Data? = nil,
        revisionError: Error? = nil
    ) {
        self.presetError = presetError
        self.resolveError = resolveError
        self.resolveData = resolveData
        self.recommendationError = recommendationError
        self.recommendationData = recommendationData
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
        if let resolveData {
            return resolveData
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
        if let recommendationData {
            return recommendationData
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

private final class DelayedOccasionService: OccasionServiceProtocol {
    func resolve(
        query: String,
        formalityHint: FormalityBand?
    ) async throws -> OccasionResolution {
        try await Task.sleep(nanoseconds: 400_000_000)
        let profile = LocalPresetCatalog.choices[0]
        return OccasionResolution(
            response: OccasionResolveResponse(
                query: query,
                profile: profile,
                matchType: "generated",
                confidence: 0.9,
                cached: false,
                alternatives: [],
                warning: nil,
                requestID: "delayed-test"
            ),
            sourceLabel: "AI result"
        )
    }
}

private final class ScriptedRecommendationService: RecommendationServiceProtocol {
    private var results: [Result<RecommendationResponse, Error>]

    init(results: [Result<RecommendationResponse, Error>]) {
        self.results = results
    }

    func recommend(
        context: RecommendationContext,
        garments: [Garment]
    ) async throws -> RecommendationResponse {
        guard !results.isEmpty else {
            throw APIError.network("No scripted response")
        }
        return try results.removeFirst().get()
    }

    func revise(
        context: RecommendationContext,
        currentOutfit: Outfit,
        replacement: Garment,
        garments: [Garment]
    ) async throws -> OutfitRevisionResponse {
        throw APIError.server(status: 503, code: nil, message: "Not used")
    }
}
