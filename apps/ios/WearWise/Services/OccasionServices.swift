import Foundation

protocol PresetServiceProtocol {
    func loadPresets() async -> PresetLoadResult
}

final class PresetService: PresetServiceProtocol {
    private let api: APIClientProtocol
    private let defaults: UserDefaults
    private let cacheKey = "wearwise.presets.response"
    private let versionKey = "wearwise.presets.version"

    init(
        api: APIClientProtocol = APIClient(),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.defaults = defaults
    }

    func loadPresets() async -> PresetLoadResult {
        let cachedVersion = defaults.object(forKey: versionKey) as? Int
        do {
            let data = try await api.fetchPresets(version: cachedVersion)
            let response = try JSONCoding.decoder.decode(
                PresetListResponse.self,
                from: data
            )
            defaults.set(data, forKey: cacheKey)
            defaults.set(response.version, forKey: versionKey)
            return PresetLoadResult(response: response, source: .remote)
        } catch let error as APIError {
            if case .notModified = error, let cached = cachedResponse() {
                return PresetLoadResult(response: cached, source: .cache)
            }
            if let cached = cachedResponse() {
                return PresetLoadResult(response: cached, source: .cache)
            }
            return bundledResult()
        } catch {
            if let cached = cachedResponse() {
                return PresetLoadResult(response: cached, source: .cache)
            }
            return bundledResult()
        }
    }

    private func cachedResponse() -> PresetListResponse? {
        guard let data = defaults.data(forKey: cacheKey) else {
            return nil
        }
        return try? JSONCoding.decoder.decode(PresetListResponse.self, from: data)
    }

    private func bundledResult() -> PresetLoadResult {
        PresetLoadResult(
            response: PresetListResponse(
                version: 1,
                cached: true,
                generatedAt: nil,
                presets: LocalPresetCatalog.choices
            ),
            source: .bundled
        )
    }
}

protocol OccasionServiceProtocol {
    func resolve(
        query: String,
        formalityHint: FormalityBand?
    ) async throws -> OccasionResolution
}

final class OccasionService: OccasionServiceProtocol {
    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func resolve(
        query: String,
        formalityHint: FormalityBand?
    ) async throws -> OccasionResolution {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            throw APIError.server(
                status: 422,
                code: "VALIDATION_ERROR",
                message: "请先输入场合。"
            )
        }

        if let local = LocalPresetCatalog.resolve(
            cleanQuery,
            formalityHint: formalityHint
        ), local.matchType != "fallback" {
            return OccasionResolution(
                response: local,
                sourceLabel: "本地预设"
            )
        }

        let request = OccasionResolveRequest(
            requestID: "ios-\(UUID().uuidString.lowercased())",
            query: cleanQuery,
            locale: "zh-CN",
            formalityHint: formalityHint
        )

        do {
            let data = try await api.resolveOccasion(request)
            let response = try JSONCoding.decoder.decode(
                OccasionResolveResponse.self,
                from: data
            )
            return OccasionResolution(
                response: response,
                sourceLabel: "后端结果"
            )
        } catch let error as APIError where error.statusCode == 422 {
            throw error
        } catch {
            guard let fallback = LocalPresetCatalog.resolve(
                cleanQuery,
                formalityHint: formalityHint
            ) else {
                throw error
            }
            return OccasionResolution(
                response: fallback,
                sourceLabel: "本地备用"
            )
        }
    }
}
