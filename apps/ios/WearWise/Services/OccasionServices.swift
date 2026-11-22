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
                version: 3,
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
                message: "Please enter an occasion."
            )
        }

        let localMatch = LocalPresetCatalog.resolve(
            cleanQuery,
            formalityHint: formalityHint
        )
        if let local = localMatch,
            local.matchType != "fallback",
            local.profile.id != "night-out",
            local.matchType != "generated"
        {
            return OccasionResolution(
                response: local,
                sourceLabel: "Local rules"
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
            if
                localMatch?.profile.id == "night-out",
                response.profile.id != "night-out"
                    || response.profile.targetFormality != .casual
            {
                return OccasionResolution(
                    response: localMatch!,
                    sourceLabel: "Fallback result"
                )
            }
            return OccasionResolution(
                response: response,
                sourceLabel: resolutionSourceLabel(for: response)
            )
        } catch let error as APIError where error.statusCode == 422 {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            guard let fallback = LocalPresetCatalog.resolve(
                cleanQuery,
                formalityHint: formalityHint
            ) else {
                throw error
            }
            return OccasionResolution(
                response: fallback,
                sourceLabel: "Fallback result"
            )
        }
    }

    private func resolutionSourceLabel(
        for response: OccasionResolveResponse
    ) -> String {
        if response.cached {
            return "Cached result"
        }
        if response.matchType == "generated" {
            return "AI result"
        }
        return "Local rules"
    }
}
