import Foundation

enum APIError: LocalizedError {
    case notModified
    case network(String)
    case invalidResponse
    case server(status: Int, code: String?, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notModified:
            "内容没有变化。"
        case let .network(message):
            message
        case .invalidResponse:
            "服务器返回了无法识别的响应。"
        case let .server(_, _, message):
            message
        case let .decoding(message):
            "数据格式无法识别：\(message)"
        }
    }

    var statusCode: Int? {
        if case let .server(status, _, _) = self {
            return status
        }
        return nil
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
            configuration.timeoutIntervalForRequest = 4
            configuration.timeoutIntervalForResource = 8
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
        return try await send(path: "/v1/presets", method: "GET", query: query)
    }

    func resolveOccasion(_ request: OccasionResolveRequest) async throws -> Data {
        try await send(
            path: "/v1/occasions/resolve",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func createRecommendations(_ request: RecommendationRequest) async throws -> Data {
        try await send(
            path: "/v1/recommendations",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    func reviseOutfit(_ request: OutfitRevisionRequest) async throws -> Data {
        try await send(
            path: "/v1/outfits/revise",
            method: "POST",
            body: try encoder.encode(request)
        )
    }

    private func send(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
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
        request.timeoutInterval = 4
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
                message: payload?.message ?? "请求失败，请稍后重试。"
            )
        }
        return data
    }
}

private struct ErrorResponse: Decodable {
    let code: String
    let message: String
}
