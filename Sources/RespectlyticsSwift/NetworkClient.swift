//
//  NetworkClient.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation

/// Handles HTTP communication with the Respectlytics API
final class NetworkClient {
    
    private var apiKey: String?
    private let apiEndpoint = URL(string: "https://respectlytics.com/api/v1/events/")!
    private let session: URLSession
    private let encoder = JSONEncoder()
    
    private let maxRetries = 3
    private let timeout: TimeInterval = 30
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config)
    }
    
    func configure(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Send events to the API
    func send(events: [Event]) async throws {
        guard let apiKey = apiKey else {
            throw NetworkError.notConfigured
        }
        
        for event in events {
            try await sendEvent(event, apiKey: apiKey, attempt: 1)
        }
    }
    
    private func sendEvent(_ event: Event, apiKey: String, attempt: Int) async throws {
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-App-Key")
        
        request.httpBody = try encoder.encode(event)
        
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
