//
//  IntegrationTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//
//  Integration tests that verify actual API responses
//
//  Setup:
//    1. cp .env.testing.example .env.testing
//    2. Edit .env.testing with your API key
//    3. source .env.testing && swift test --filter IntegrationTests
//

import XCTest
@testable import RespectlyticsSwift

/// Integration tests that verify real API responses
/// These tests require a running API server and valid API key
final class IntegrationTests: XCTestCase {

    private var apiKey: String!
    private var eventsURL: String!

    // Track test results for summary
    private static var testResults: [(name: String, passed: Bool, detail: String)] = []
    private static var environmentPrinted = false

    override func setUp() async throws {
        // Print environment status once at the start of test run
        if !Self.environmentPrinted {
            TestConfiguration.printEnvironmentStatus()
            Self.environmentPrinted = true
            Self.testResults = []
            print("🧪 Running Integration Tests (v3.1.2 - Session-Based Analytics)...")
        }

        // Check for API key - tests will be skipped if not set
        guard let key = TestConfiguration.apiKey else {
            throw XCTSkip("⏭️  Skipping: No API key set (set RESPECTLYTICS_TEST_API_KEY)")
        }
        apiKey = key
        eventsURL = TestConfiguration.activeEventsURL
    }

    // MARK: - Test: Valid Event Submission (201)

    /// Verify that a valid event returns 201 Created
    func testEventSubmission_Returns201() async throws {
        let testName = "testEventSubmission"

        // Build event payload (no user_id in v2.0.0+)
        let event = buildTestEvent(name: "sdk_test_valid_event")

        // Send directly to API
        let (statusCode, _) = try await sendEvent(event)

        // Verify 201 Created
        if statusCode == 201 {
            recordResult(testName, passed: true, detail: "201 Created")
            XCTAssertEqual(statusCode, 201)
        } else {
            recordResult(testName, passed: false, detail: "Expected 201, got \(statusCode)")
            XCTFail("Expected 201 Created, got \(statusCode)")
        }
    }

    // MARK: - Test: Invalid API Key (401)

    /// Verify that an invalid API key returns 401 Unauthorized
    func testInvalidApiKey_Returns401() async throws {
        let testName = "testInvalidApiKey"

        // Build event with valid structure
        let event = buildTestEvent(name: "sdk_test_invalid_key")

        // Send with invalid API key
        let (statusCode, _) = try await sendEvent(event, overrideApiKey: "invalid-api-key-12345")

        // Verify 401 Unauthorized
        if statusCode == 401 {
            recordResult(testName, passed: true, detail: "401 Unauthorized")
            XCTAssertEqual(statusCode, 401)
        } else {
            recordResult(testName, passed: false, detail: "Expected 401, got \(statusCode)")
            XCTFail("Expected 401 Unauthorized, got \(statusCode)")
        }
    }

    // MARK: - Test: Missing Event Name (400)

    /// Verify that missing event_name returns 400 Bad Request
    func testMissingEventName_Returns400() async throws {
        let testName = "testMissingEventName"

        // Build event without event_name
        var event = buildTestEvent(name: "")
        event["event_name"] = nil  // Remove event_name

        // Send to API
        let (statusCode, body) = try await sendEvent(event)

        // Verify 400 Bad Request
        if statusCode == 400 {
            recordResult(testName, passed: true, detail: "400 Bad Request")
            XCTAssertEqual(statusCode, 400)
        } else {
            recordResult(testName, passed: false, detail: "Expected 400, got \(statusCode). Body: \(body ?? "nil")")
            XCTFail("Expected 400 Bad Request, got \(statusCode)")
        }
    }

    // MARK: - Test: Event with user_id is REJECTED (400)

    /// Verify that events with user_id are rejected by the backend
    /// This is the key v2.0.0 test - backend should reject user_id field
    func testEventWithUserId_Returns400() async throws {
        let testName = "testUserIdRejected"

        // Build event with user_id (should be rejected)
        var event = buildTestEvent(name: "sdk_test_with_user")
        event["user_id"] = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        // Send to API
        let (statusCode, body) = try await sendEvent(event)

        // Verify 400 Bad Request - user_id is no longer accepted
        if statusCode == 400 {
            recordResult(testName, passed: true, detail: "400 Bad Request (user_id rejected as expected)")
            XCTAssertEqual(statusCode, 400)
            // Verify error message mentions user_id
            if let responseBody = body {
                XCTAssertTrue(responseBody.contains("user_id") || responseBody.contains("not allowed"),
                            "Error response should mention user_id is not allowed")
            }
        } else {
            recordResult(testName, passed: false, detail: "Expected 400 (user_id rejected), got \(statusCode)")
            XCTFail("Expected 400 Bad Request for user_id field, got \(statusCode). Body: \(body ?? "nil")")
        }
    }

    // MARK: - Test: Event without Screen (201)

    /// Verify that events without screen parameter are accepted
    func testEventWithoutScreen_Returns201() async throws {
        let testName = "testEventWithoutScreen"

        // Build event without screen (standard event, no deprecated fields)
        let event = buildTestEvent(name: "sdk_test_no_screen")

        // Send to API
        let (statusCode, _) = try await sendEvent(event)

        // Verify 201 Created
        if statusCode == 201 {
            recordResult(testName, passed: true, detail: "201 Created")
            XCTAssertEqual(statusCode, 201)
        } else {
            recordResult(testName, passed: false, detail: "Expected 201, got \(statusCode)")
            XCTFail("Expected 201 Created, got \(statusCode)")
        }
    }

    // MARK: - Test: Event with Properties (201)

    /// Verify that the body the SDK builds for an event with properties is accepted,
    /// and that the answer names what was kept and what was ignored (v3.1.0)
    func testEventWithProperties_Returns201() async throws {
        let testName = "testEventWithProperties"

        // Built and encoded by the SDK itself, exactly as track(_:properties:) sends it
        let filtered = PropertyFilter.filter(["paywall": "b", "price": 7.5, "Bad Name": "b"])
        let event = Event(
            eventName: "sdk_test_properties",
            sessionId: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            properties: filtered.kept
        )
        let client = NetworkClient()
        client.configure(apiKey: apiKey, apiEndpoint: URL(string: eventsURL)!)
        let request = try client.request(for: event, apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        // An undeclared property is ignored by the server, never a reason to refuse the event
        if statusCode == 201, json?["properties"] is [String: Any], json?["ignored_properties"] is [Any] {
            recordResult(testName, passed: true, detail: "201 Created with properties and ignored_properties")
        } else {
            let body = String(data: data, encoding: .utf8) ?? "nil"
            recordResult(testName, passed: false, detail: "Expected 201 with properties, got \(statusCode). Body: \(body)")
            XCTFail("Expected 201 with properties and ignored_properties, got \(statusCode). Body: \(body)")
        }
    }

    // MARK: - Test Summary (runs last alphabetically)

    func testZZ_PrintSummary() async throws {
        // Print summary of all test results
        print("")
        let passed = Self.testResults.filter { $0.passed }.count
        let total = Self.testResults.count

        for result in Self.testResults {
            let icon = result.passed ? "✅" : "❌"
            print("   ├─ \(result.name): \(icon) \(result.passed ? "PASS" : "FAIL") (\(result.detail))")
        }

        print("")
        if passed == total {
            print("📊 Results: \(passed)/\(total) tests passed ✅")
        } else {
            print("📊 Results: \(passed)/\(total) tests passed ⚠️")
        }
        print("")

        // This test always passes - it's just for output
        XCTAssertTrue(true)
    }

    // MARK: - Helpers

    private func buildTestEvent(name: String) -> [String: Any] {
        let event: [String: Any] = [
            "event_name": name,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "session_id": UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            "platform": "iOS"
        ]
        // Note: Only 4 fields sent by SDK. Country is derived server-side.
        // user_id is NOT included - v2.0.0+ session-based analytics

        return event
    }

    private func sendEvent(_ event: [String: Any], overrideApiKey: String? = nil) async throws -> (statusCode: Int, body: String?) {
        guard let url = URL(string: eventsURL) else {
            throw TestError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(overrideApiKey ?? apiKey, forHTTPHeaderField: "X-App-Key")
        request.timeoutInterval = 10.0

        let jsonData = try JSONSerialization.data(withJSONObject: event)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse
        }

        let body = String(data: data, encoding: .utf8)
        return (httpResponse.statusCode, body)
    }

    private func recordResult(_ name: String, passed: Bool, detail: String) {
        Self.testResults.append((name: name, passed: passed, detail: detail))
    }

    enum TestError: Error {
        case invalidURL
        case invalidResponse
    }
}
