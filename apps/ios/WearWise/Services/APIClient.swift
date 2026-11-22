import Foundation

enum APIError: LocalizedError {
    case notModified
    case network(String)
    case timeout
    case invalidResponse
    case server(status: Int, code: String?, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notModified:
            "The content has not changed."
        case let .network(message):
            message
        case .timeout:
            "The request timed out. Try again or use local rules."
        case .invalidResponse:
            "The server returned an unreadable response."
        case let .server(_, _, message):
            message
        case let .decoding(message):
            "The response format is invalid: \(message)"
        }
    }

    var statusCode: Int? {
        if case let .server(status, _, _) = self {
            return status
        }
        return nil
    }

    var isTimeout: Bool {
        if case .timeout = self {
            return true
        }
        return false
    }
}

enum AppConfiguration {
    static var apiBaseURL: URL {
        if
            let value = ProcessInfo.processInfo.environment["WEARWISE_API_BASE_URL"],
            let url = URL(string: value)
        {
            return url
        }
        if
            let value = UserDefaults.standard.string(forKey: "wearwise.api.base_url"),
            let url = URL(string: value)
        {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }
}

enum APIRequestTimeout {
    static let presets: TimeInterval = 5
    static let occasionResolution: TimeInterval = 15
    static let recommendations: TimeInterval = 20
    static let outfitRevision: TimeInterval = 15
    static let weatherCurrent: TimeInterval = 8
}

enum JSONCoding {
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

protocol APIClientProtocol {
    func fetchPresets(version: Int?) async throws -> Data
    func resolveOccasion(_ request: OccasionResolveRequest) async throws -> Data
    func createRecommendations(_ request: RecommendationRequest) async throws -> Data
    func reviseOutfit(_ request: OutfitRevisionRequest) async throws -> Data
}

struct APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 25
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
        self.encoder = JSONCoding.encoder
    }

    func fetchPresets(version: Int?) async throws -> Data {
        var query: [URLQueryItem] = []
        if let version {
            query.append(URLQueryItem(name: "version", value: String(version)))
        }
        return try await send(
            path: "/v1/presets",
            method: "GET",
            query: query,
            timeout: APIRequestTimeout.presets
        )
    }

    func resolveOccasion(_ request: OccasionResolveRequest) async throws -> Data {
        try await send(
            path: "/v1/occasions/resolve",
            method: "POST",
            body: try encoder.encode(request),
            timeout: APIRequestTimeout.occasionResolution
        )
    }

    func createRecommendations(_ request: RecommendationRequest) async throws -> Data {
        try await send(
            path: "/v1/recommendations",
            method: "POST",
            body: try encoder.encode(request),
            timeout: APIRequestTimeout.recommendations
        )
    }

    func reviseOutfit(_ request: OutfitRevisionRequest) async throws -> Data {
        try await send(
            path: "/v1/outfits/revise",
            method: "POST",
            body: try encoder.encode(request),
            timeout: APIRequestTimeout.outfitRevision
        )
    }

    private func send(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        timeout: TimeInterval
    ) async throws -> Data {
        guard
            var components = URLComponents(
                url: baseURL.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
            )
        else {
            throw APIError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if
                let urlError = error as? URLError,
                urlError.code == .timedOut
            {
                throw APIError.timeout
            }
            throw APIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 304 {
            throw APIError.notModified
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONCoding.decoder.decode(ErrorResponse.self, from: data)
            throw APIError.server(
                status: httpResponse.statusCode,
                code: payload?.code,
                message: payload?.message ?? "Request failed. Please try again."
            )
        }
        return data
    }
}

private struct ErrorResponse: Decodable {
    let code: String
    let message: String
}
