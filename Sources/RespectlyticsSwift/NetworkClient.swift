//
//  NetworkClient.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation

/// Handles HTTP communication with the Respectlytics API
final class NetworkClient {

    private var apiKey: String?
    private var apiEndpoint: URL = URL(string: "https://respectlytics.com/api/v1/events/")!
    private let session: URLSession
    private let encoder = JSONEncoder()

    private let maxRetries = 3
    private let timeout: TimeInterval = 30

    /// - Parameter session: The session to send with; tests pass one with a stub protocol.
    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeout
            config.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: config)
        }
    }

    func configure(apiKey: String, apiEndpoint: URL? = nil) {
        self.apiKey = apiKey
        if let apiEndpoint = apiEndpoint {
            self.apiEndpoint = apiEndpoint
        }
    }

    /// Send one event to the API.
    ///
    /// Network errors and 429 are retried with backoff, and anything worth trying
    /// again later (network errors, 429, 5xx) is thrown, so the queue keeps the event.
    /// A 401 is thrown at once and never retried: the queue then stops sending.
    ///
    /// A 400 is final, since no retry can change it. An event with properties is
    /// then sent once more without them, for a server older than 3.1.0 (a self-hosted
    /// Community Edition not yet updated) that refuses the `properties` field. If the
    /// server refuses the event itself, it is dropped, so it never holds up the
    /// events queued after it.
    func send(_ event: Event) async throws {
        guard let apiKey = apiKey else {
            throw NetworkError.notConfigured
        }

        do {
            try await sendEvent(event, apiKey: apiKey, attempt: 1)
            return
        } catch NetworkError.badRequest {
            // Final: handled below
        }

        if event.properties != nil {
            do {
                try await sendEvent(event.withoutProperties, apiKey: apiKey, attempt: 1)
                print("[Respectlytics] ⚠️ Server refused the properties, event sent without them")
                return
            } catch NetworkError.badRequest {
                // Final: the event itself is refused
            }
        }

        print("[Respectlytics] ⚠️ Server refused an event (400), dropped")
    }

    /// The POST that carries one event. `properties` is in the body only when the event has some.
    func request(for event: Event, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-App-Key")

        request.httpBody = try encoder.encode(event)
        return request
    }

    private func sendEvent(_ event: Event, apiKey: String, attempt: Int) async throws {
        let request = try request(for: event, apiKey: apiKey)

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return // Success
            case 401:
                throw NetworkError.unauthorized
            case 400:
                throw NetworkError.badRequest
            case 429:
                // Rate limited - retry with backoff
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try await sendEvent(event, apiKey: apiKey, attempt: attempt + 1)
                } else {
                    throw NetworkError.rateLimited
                }
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            // Network error - retry with backoff
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await sendEvent(event, apiKey: apiKey, attempt: attempt + 1)
            } else {
                throw NetworkError.networkError(error)
            }
        }
    }
}

enum NetworkError: Error {
    case notConfigured
    case invalidResponse
    case unauthorized
    case badRequest
    case rateLimited
    case serverError(Int)
    case networkError(Error)
}
