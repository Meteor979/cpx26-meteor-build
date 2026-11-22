import CryptoKit
import Foundation

protocol WeatherServiceProtocol {
    func fetchCurrentWeather(_ request: WeatherRequest) async throws -> WeatherResponse
}

final class WeatherService: WeatherServiceProtocol {
    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func fetchCurrentWeather(_ request: WeatherRequest) async throws -> WeatherResponse {
        let data = try await api.fetchCurrentWeather(request)
        return try JSONCoding.decoder.decode(WeatherResponse.self, from: data)
    }
}

struct WeatherCoordinates {
    let latitude: Double
    let longitude: Double
    let accuracyM: Double
    let timezone: String

    var timezoneIdentifier: String {
        timezone
    }

    func cacheKeyHash(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        let source = String(
            format: "%.2f|%.2f|%@|%@",
            latitude,
            longitude,
            formatter.string(from: now),
            timezone
        )
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct WeatherCacheEntry: Codable {
    let keyHash: String
    let weather: WeatherData
    let source: WeatherSource
    let observedAt: String?
    let locationLabel: String?
    let fetchedAt: Date
}

final class WeatherCacheStore {
    private let defaults: UserDefaults
    private let cacheKey = "wearwise.weather.cache.v1"
    private let maxAge: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        maxAge: TimeInterval = 3_600
    ) {
        self.defaults = defaults
        self.maxAge = maxAge
    }

    func save(
        response: WeatherResponse,
        keyHash: String,
        fetchedAt: Date = Date()
    ) {
        guard let weather = response.weather else {
            return
        }
        let entry = WeatherCacheEntry(
            keyHash: keyHash,
            weather: weather,
            source: response.source,
            observedAt: response.observedAt,
            locationLabel: response.locationLabel,
            fetchedAt: fetchedAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entry) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    func loadForLocation(
        keyHash: String,
        now: Date = Date()
    ) -> WeatherCacheEntry? {
        guard
            let entry = loadLatest(now: now),
            entry.keyHash == keyHash
        else {
            return nil
        }
        return entry
    }

    func loadLatest(now: Date = Date()) -> WeatherCacheEntry? {
        guard let data = defaults.data(forKey: cacheKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let entry = try? decoder.decode(WeatherCacheEntry.self, from: data),
            now.timeIntervalSince(entry.fetchedAt) < maxAge,
            now.timeIntervalSince(entry.fetchedAt) >= 0
        else {
            defaults.removeObject(forKey: cacheKey)
            return nil
        }
        return entry
    }
}
