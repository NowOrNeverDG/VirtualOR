import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "APIService")

final class APIService: Sendable {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeoutInterval
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func request<T: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest: URLRequest
        do {
            urlRequest = try endpoint.urlRequest()
        } catch {
            logger.error("Failed to build request: \(error.localizedDescription)")
            throw error
        }

        logger.debug("[\(endpoint.method.rawValue)] \(urlRequest.url?.absoluteString ?? "")")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("HTTP \(httpResponse.statusCode)")
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func request(_ endpoint: APIEndpoint) async throws {
        let urlRequest: URLRequest
        do {
            urlRequest = try endpoint.urlRequest()
        } catch {
            logger.error("Failed to build request: \(error.localizedDescription)")
            throw error
        }

        logger.debug("[\(endpoint.method.rawValue)] \(urlRequest.url?.absoluteString ?? "")")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("HTTP \(httpResponse.statusCode)")
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}
