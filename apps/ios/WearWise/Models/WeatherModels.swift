import Foundation

enum WeatherResponseStatus: String, Codable, Equatable {
    case ok
    case stale
    case unavailable
}

enum WeatherSource: String, Codable, Equatable {
    case remoteWeather = "remote_weather"
    case cache
    case mock
    case fallback
}

struct WeatherRequest: Encodable {
    let requestID: String
    let latitude: Double
    let longitude: Double
    let accuracyM: Double?
    let timezone: String
    let targetAt: String?

    enum CodingKeys: String, CodingKey {
        case requestID = "requestId"
        case latitude
        case longitude
        case accuracyM
        case timezone
        case targetAt
    }
}

struct WeatherResponse: Decodable {
    let status: WeatherResponseStatus
    let locationLabel: String?
    let weather: WeatherData?
    let observedAt: String?
    let timezone: String?
    let cached: Bool
    let source: WeatherSource
    let warning: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case status
        case locationLabel
        case weather
        case observedAt
        case timezone
        case cached
        case source
        case warning
        case requestID = "requestId"
    }
}

enum WeatherContextStatus: String, Equatable {
    case demo
    case loading
    case ok
    case stale
    case unavailable
    case permissionDenied
}

struct WeatherContext: Equatable {
    let weather: WeatherData
    let status: WeatherContextStatus
    let source: WeatherSource
    let locationLabel: String?
    let observedAt: String?
    let updatedAt: Date?

    var isDemo: Bool {
        source == .mock
    }

    static let demo = WeatherContext(
        weather: .demo,
        status: .demo,
        source: .mock,
        locationLabel: nil,
        observedAt: nil,
        updatedAt: nil
    )

    static func from(
        response: WeatherResponse,
        fetchedAt: Date = Date()
    ) -> WeatherContext? {
        guard let weather = response.weather else {
            return nil
        }
        switch response.status {
        case .ok:
            return WeatherContext(
                weather: weather,
                status: .ok,
                source: response.source,
                locationLabel: response.locationLabel,
                observedAt: response.observedAt,
                updatedAt: fetchedAt
            )
        case .stale:
            return WeatherContext(
                weather: weather,
                status: .stale,
                source: response.source,
                locationLabel: response.locationLabel,
                observedAt: response.observedAt,
                updatedAt: fetchedAt
            )
        case .unavailable:
            return nil
        }
    }
}

extension WeatherData {
    var conditionLabel: String {
        switch condition {
        case "clear": "Clear"
        case "partly_cloudy": "Partly cloudy"
        case "cloudy": "Cloudy"
        case "rain": "Rain"
        case "snow": "Snow"
        case "storm": "Storm"
        case "fog": "Fog"
        default: "Unknown"
        }
    }

    var summaryLine: String {
        "\(Int(temperatureC.rounded()))°C · \(conditionLabel)"
    }

    var detailLine: String {
        "Feels like \(Int(feelsLikeC.rounded()))°C"
    }

    var rainLine: String {
        "\(Int((precipitationProbability * 100).rounded()))% rain"
    }
}
