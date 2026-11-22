import CoreLocation
import XCTest
@testable import WearWise

final class WeatherContextTests: XCTestCase {
    func testWeatherResponseDecodesSnakeCase() throws {
        let data = Data(
            """
            {
              "status": "ok",
              "location_label": "Shanghai",
              "weather": {
                "temperature_c": 16,
                "feels_like_c": 15,
                "condition": "partly_cloudy",
                "precipitation_probability": 0.2,
                "wind_speed_kph": 12
              },
              "observed_at": "2026-11-22T09:00:00+08:00",
              "timezone": "Asia/Shanghai",
              "cached": false,
              "source": "remote_weather",
              "warning": null,
              "request_id": "ios-weather-1"
            }
            """.utf8
        )

        let response = try JSONCoding.decoder.decode(
            WeatherResponse.self,
            from: data
        )

        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.locationLabel, "Shanghai")
        XCTAssertEqual(response.weather?.temperatureC, 16)
        XCTAssertEqual(response.requestID, "ios-weather-1")
    }

    func testOkResponseBecomesWeatherContext() throws {
        let response = makeResponse(
            status: .ok,
            temperature: 12,
            source: .remoteWeather
        )
        let context = try XCTUnwrap(
            WeatherContext.from(response: response)
        )

        XCTAssertEqual(context.status, .ok)
        XCTAssertEqual(context.weather.feelsLikeC, 11)
        XCTAssertFalse(context.isDemo)
        XCTAssertEqual(context.source, .remoteWeather)
    }

    @MainActor
    func testUnavailableNullWeatherFallsBackToDemo() async throws {
        let store = try makeStore(
            service: StubWeatherService(
                result: .success(
                    makeResponse(
                        status: .unavailable,
                        temperature: nil,
                        source: .fallback
                    )
                )
            )
        )

        await store.loadWeather(for: coordinates())
        let context = store.context

        XCTAssertEqual(context.status, .unavailable)
        XCTAssertTrue(context.isDemo)
        XCTAssertEqual(context.weather.temperatureC, WeatherData.demo.temperatureC)
    }

    @MainActor
    func testNetworkErrorFallsBackToDemo() async throws {
        let store = try makeStore(
            service: StubWeatherService(
                result: .failure(APIError.network("offline"))
            )
        )

        await store.loadWeather(for: coordinates())
        let context = store.context

        XCTAssertEqual(context.status, .unavailable)
        XCTAssertTrue(context.isDemo)
    }

    @MainActor
    func testHTTPValidationAndServiceErrorsFallBackToDemo() async throws {
        let errors = [
            APIError.server(
                status: 422,
                code: "VALIDATION_ERROR",
                message: "Invalid weather request"
            ),
            APIError.server(
                status: 503,
                code: "PROVIDER_UNAVAILABLE",
                message: "Weather provider unavailable"
            )
        ]

        for error in errors {
            let store = try makeStore(
                service: StubWeatherService(result: .failure(error))
            )
            await store.loadWeather(for: coordinates())
            let context = store.context
            XCTAssertEqual(context.status, .unavailable)
            XCTAssertTrue(context.isDemo)
        }
    }

    @MainActor
    func testFreshCacheDoesNotRepeatRequest() async throws {
        let now = Date()
        let location = coordinates()
        let service = StubWeatherService(
            result: .success(
                makeResponse(status: .ok, temperature: 22, source: .remoteWeather)
            )
        )
        let store = try makeStore(service: service)
        let keyHash = location.cacheKeyHash(now: now)
        store.cache.save(
            response: makeResponse(
                status: .ok,
                temperature: 18,
                source: .remoteWeather
            ),
            keyHash: keyHash,
            fetchedAt: now
        )

        await store.loadWeather(for: location)
        let context = store.context

        XCTAssertEqual(service.callCount, 0)
        XCTAssertEqual(context.source, .cache)
        XCTAssertEqual(context.weather.temperatureC, 18)
    }

    @MainActor
    func testNetworkFailureUsesValidCachedWeather() async throws {
        let store = try makeStore(
            service: StubWeatherService(
                result: .failure(APIError.network("offline"))
            )
        )
        store.cache.save(
            response: makeResponse(
                status: .ok,
                temperature: 14,
                source: .remoteWeather
            ),
            keyHash: "another-location",
            fetchedAt: Date()
        )

        await store.loadWeather(for: coordinates())
        let context = store.context

        XCTAssertEqual(context.source, .cache)
        XCTAssertEqual(context.status, .stale)
        XCTAssertEqual(context.weather.temperatureC, 14)
    }

    @MainActor
    func testExpiredCacheRequestsFreshWeather() async throws {
        let location = coordinates()
        let service = StubWeatherService(
            result: .success(
                makeResponse(status: .ok, temperature: 21, source: .remoteWeather)
            )
        )
        let store = try makeStore(service: service)
        store.cache.save(
            response: makeResponse(
                status: .ok,
                temperature: 8,
                source: .remoteWeather
            ),
            keyHash: location.cacheKeyHash(now: Date()),
            fetchedAt: Date().addingTimeInterval(-3_700)
        )

        await store.loadWeather(for: location)
        let context = store.context

        XCTAssertEqual(service.callCount, 1)
        XCTAssertEqual(context.weather.temperatureC, 21)
    }

    @MainActor
    func testDeniedLocationStillGeneratesRecommendations() async throws {
        let store = try makeStore(service: StubWeatherService(
            result: .failure(APIError.network("offline"))
        ))
        store.handleAuthorization(.denied)
        let garments = makeCoreGarments()
        let recommendation = StubRecommendationService(garments: garments)
        let viewModel = OccasionRecommendationViewModel(
            recommendationService: recommendation,
            weatherContext: store.context
        )

        await viewModel.generateRecommendations(garments: garments)
        let deniedContext = store.context
        let recommendationCount = viewModel.recommendations.count

        XCTAssertEqual(deniedContext.status, .permissionDenied)
        XCTAssertTrue(deniedContext.isDemo)
        XCTAssertEqual(recommendationCount, 3)
    }

    @MainActor
    func testRecommendationUsesCurrentWeatherData() async throws {
        let garments = makeCoreGarments()
        let service = StubRecommendationService(garments: garments)
        let vm = OccasionRecommendationViewModel(
            recommendationService: service
        )
        let weather = WeatherData(
            temperatureC: 7,
            feelsLikeC: 5,
            condition: "rain",
            precipitationProbability: 0.8,
            windSpeedKph: 20
        )
        let context = WeatherContext(
            weather: weather,
            status: .ok,
            source: .remoteWeather,
            locationLabel: "Shanghai",
            observedAt: nil,
            updatedAt: Date()
        )
        vm.updateWeatherContext(context)

        await vm.generateRecommendations(garments: garments)

        XCTAssertEqual(service.lastContext?.weather, weather)
    }

    @MainActor
    func testWeatherRefreshFailureKeepsExistingRecommendations() async throws {
        let garments = makeCoreGarments()
        let vm = OccasionRecommendationViewModel(
            recommendationService: StubRecommendationService(garments: garments)
        )
        await vm.generateRecommendations(garments: garments)
        let countBefore = vm.recommendations.count

        let store = try makeStore(service: StubWeatherService(
            result: .failure(APIError.network("offline"))
        ))
        await store.loadWeather(for: coordinates())
        vm.updateWeatherContext(store.context)
        let remainingCount = vm.recommendations.count

        XCTAssertEqual(remainingCount, countBefore)
        XCTAssertEqual(remainingCount, 3)
    }

    func testWeatherUISourceUsesEnglishStaticCopy() throws {
        for phrase in [
            WeatherUICopy.weather,
            WeatherUICopy.useCurrent,
            WeatherUICopy.update,
            WeatherUICopy.updated,
            WeatherUICopy.demo,
            WeatherUICopy.useDemo,
            WeatherUICopy.unavailable,
            WeatherUICopy.locationOff,
            WeatherUICopy.tryAgain
        ] {
            XCTAssertFalse(phrase.isEmpty)
            XCTAssertNil(
                phrase.range(of: "\\p{Han}", options: .regularExpression)
            )
        }
    }

    private func makeResponse(
        status: WeatherResponseStatus,
        temperature: Double?,
        source: WeatherSource
    ) -> WeatherResponse {
        WeatherResponse(
            status: status,
            locationLabel: status == .unavailable ? nil : "Shanghai",
            weather: temperature.map {
                WeatherData(
                    temperatureC: $0,
                    feelsLikeC: $0 - 1,
                    condition: "partly_cloudy",
                    precipitationProbability: 0.2,
                    windSpeedKph: 12
                )
            },
            observedAt: "2026-11-22T09:00:00+08:00",
            timezone: "Asia/Shanghai",
            cached: false,
            source: source,
            warning: nil,
            requestID: "ios-weather-test"
        )
    }

    private func coordinates() -> WeatherCoordinates {
        WeatherCoordinates(
            latitude: 31.23,
            longitude: 121.47,
            accuracyM: 1_200,
            timezone: "Asia/Shanghai"
        )
    }

    @MainActor
    private func makeStore(
        service: WeatherServiceProtocol
    ) throws -> WeatherContextStore {
        let suiteName = "WearWiseWeather-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(true, forKey: "wearwise.weather.enabled")
        let cache = WeatherCacheStore(defaults: defaults)
        let store = WeatherContextStore(
            service: service,
            cache: cache,
            locationManager: CLLocationManager(),
            defaults: defaults
        )
        return store
    }

    private func makeCoreGarments() -> [Garment] {
        [
            makeGarment(name: "Shirt", slot: .top),
            makeGarment(name: "Trousers", slot: .bottom),
            makeGarment(name: "Shoes", slot: .shoes)
        ]
    }

    private func makeGarment(name: String, slot: GarmentSlot) -> Garment {
        Garment(
            id: UUID(),
            localPhotoPath: "\(UUID().uuidString).jpg",
            thumbnailPath: "\(UUID().uuidString)-thumb.jpg",
            capturedAt: Date(),
            name: name,
            slot: slot,
            category: slot.rawValue,
            colors: ["Black"],
            pattern: "Solid",
            fit: "Regular",
            material: "Cotton",
            formalityScore: 3,
            warmthScore: 2,
            userConfirmed: true,
            source: .manual
        )
    }
}

private final class StubWeatherService: WeatherServiceProtocol {
    let result: Result<WeatherResponse, Error>
    private(set) var callCount = 0

    init(result: Result<WeatherResponse, Error>) {
        self.result = result
    }

    func fetchCurrentWeather(_ request: WeatherRequest) async throws -> WeatherResponse {
        callCount += 1
        return try result.get()
    }
}

private final class StubRecommendationService: RecommendationServiceProtocol {
    let garments: [Garment]
    private(set) var lastContext: RecommendationContext?

    init(garments: [Garment]) {
        self.garments = garments
    }

    func recommend(
        context: RecommendationContext,
        garments: [Garment]
    ) async throws -> RecommendationResponse {
        lastContext = context
        let itemIDs = garments.map { $0.id.uuidString.lowercased() }
        return RecommendationResponse(
            outfits: (0..<3).map { index in
                Outfit(
                    id: "weather-outfit-\(index)",
                    itemIDs: itemIDs,
                    title: "Outfit \(index + 1)",
                    reasons: ["Weather context remains available."],
                    tradeoffs: [],
                    source: .mock,
                    score: 0.8
                )
            },
            requestedCount: 3,
            resultCountReason: "three_available",
            fallbackUsed: true,
            warning: nil,
            provider: "test",
            generatedAt: nil,
            requestID: "test"
        )
    }

    func revise(
        context: RecommendationContext,
        currentOutfit: Outfit,
        replacement: Garment,
        garments: [Garment]
    ) async throws -> OutfitRevisionResponse {
        throw APIError.server(status: 503, code: nil, message: "Unused")
    }
}
