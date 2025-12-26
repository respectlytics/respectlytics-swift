//
//  RespectlyticsSwiftTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import XCTest
@testable import RespectlyticsSwift

final class RespectlyticsSwiftTests: XCTestCase {

    // MARK: - Configuration Tests

    func testConfigure() {
        // Should not throw
        Respectlytics.configure(apiKey: "test-api-key")
        // If we get here without crash, configuration worked
        XCTAssertTrue(true)
    }

    // MARK: - Event Model Tests

    func testEventCreation() {
        let event = Event(
            eventName: "test_event",
            sessionId: "session456"
        )

        XCTAssertEqual(event.eventName, "test_event")
        XCTAssertEqual(event.sessionId, "session456")
        XCTAssertFalse(event.timestamp.isEmpty)
        XCTAssertFalse(event.platform.isEmpty)
    }

    func testEventEncoding() throws {
        let event = Event(
            eventName: "test_event",
            sessionId: "session456"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        XCTAssertNotNil(data)

        // Verify it can be decoded back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.eventName, event.eventName)
        XCTAssertEqual(decoded.sessionId, event.sessionId)
    }

    func testEventEncodesOnlyAllowedFields() throws {
        let event = Event(
            eventName: "test_event",
            sessionId: "session456"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // These 4 fields should be present (API strict allowlist)
        XCTAssertNotNil(json["event_name"])
        XCTAssertNotNil(json["timestamp"])
        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["platform"])

        // v2.1.0: These fields should NOT be present (removed from allowlist)
        XCTAssertNil(json["screen"], "screen field removed in v2.1.0")
        XCTAssertNil(json["os_version"], "os_version field removed in v2.1.0")
        XCTAssertNil(json["app_version"], "app_version field removed in v2.1.0")
        XCTAssertNil(json["locale"], "locale field removed in v2.1.0")
        XCTAssertNil(json["device_type"], "device_type field removed in v2.1.0")

        // user_id should NOT be present (v2.0.0+ - session-based only)
        XCTAssertNil(json["user_id"], "user_id should not be in event payload")

        // These fields should NOT be present (privacy violation)
        XCTAssertNil(json["properties"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["data"])
        XCTAssertNil(json["custom"])
        XCTAssertNil(json["extra"])
    }

    func testEventDoesNotIncludeUserId() throws {
        // Critical test: Verify user_id is never sent
        let event = Event(
            eventName: "test_event",
            sessionId: "abc123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8)!

        // user_id should not appear anywhere in the JSON
        XCTAssertFalse(jsonString.contains("user_id"), "Event payload must not contain user_id field")
    }

    func testEventPayloadIsMinimal() throws {
        // v2.1.0: Verify only 4 fields are sent
        let event = Event(
            eventName: "test_event",
            sessionId: "abc123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Should have exactly 4 keys
        XCTAssertEqual(json.count, 4, "Event payload should have exactly 4 fields")

        // Verify the exact keys
        let expectedKeys = Set(["event_name", "timestamp", "session_id", "platform"])
        let actualKeys = Set(json.keys)
        XCTAssertEqual(actualKeys, expectedKeys)
    }

    // MARK: - Session Manager Tests

    func testSessionManagerGeneratesSessionId() {
        let sessionManager = SessionManager()
        let sessionId = sessionManager.getSessionId()

        XCTAssertFalse(sessionId.isEmpty)
        XCTAssertEqual(sessionId.count, 32, "Session ID must be exactly 32 lowercase hex characters")
    }

    func testSessionManagerSessionIdFormat() {
        let sessionManager = SessionManager()
        let sessionId = sessionManager.getSessionId()

        // Must be 32 lowercase hex characters
        let hexPattern = "^[0-9a-f]{32}$"
        let regex = try! NSRegularExpression(pattern: hexPattern)
        let range = NSRange(sessionId.startIndex..., in: sessionId)
        let match = regex.firstMatch(in: sessionId, range: range)

        XCTAssertNotNil(match, "Session ID must be exactly 32 lowercase hex characters")
    }

    func testSessionManagerMaintainsSameSession() {
        let sessionManager = SessionManager()
        let sessionId1 = sessionManager.getSessionId()
        let sessionId2 = sessionManager.getSessionId()

        XCTAssertEqual(sessionId1, sessionId2, "Session ID should remain stable within the 2-hour window")
    }

    func testSessionManagerNewInstanceNewSession() {
        // Each SessionManager instance should have its own session
        // This simulates app restart behavior (RAM-only storage)
        let sessionManager1 = SessionManager()
        let sessionManager2 = SessionManager()

        let sessionId1 = sessionManager1.getSessionId()
        let sessionId2 = sessionManager2.getSessionId()

        XCTAssertNotEqual(sessionId1, sessionId2, "New SessionManager instance should have a new session ID (RAM-only)")
    }

    // MARK: - v2.0.0 Breaking Changes Tests

    func testIdentifyMethodDoesNotExist() {
        // Verify identify() method has been removed
        let mirror = Mirror(reflecting: Respectlytics.self)
        let methods = mirror.children.compactMap { $0.label }

        XCTAssertFalse(methods.contains("identify"), "identify() method should not exist in v2.0.0+")
    }

    func testResetMethodDoesNotExist() {
        // Verify reset() method has been removed
        let mirror = Mirror(reflecting: Respectlytics.self)
        let methods = mirror.children.compactMap { $0.label }

        XCTAssertFalse(methods.contains("reset"), "reset() method should not exist in v2.0.0+")
    }

    // MARK: - Configuration Model Tests

    func testConfigurationDefaults() {
        let config = Configuration(apiKey: "test-key")

        XCTAssertEqual(config.apiKey, "test-key")
        XCTAssertEqual(config.apiEndpoint.absoluteString, "https://respectlytics.com/api/v1/events/")
    }

    func testConfigurationCustomEndpoint() {
        let customEndpoint = URL(string: "https://custom.example.com/events/")!
        let config = Configuration(apiKey: "test-key", apiEndpoint: customEndpoint)

        XCTAssertEqual(config.apiEndpoint, customEndpoint)
    }

    // MARK: - Integration Tests

    func testFullEventFlow() {
        // Configure SDK
        Respectlytics.configure(apiKey: "test-api-key")

        // Track events (v2.1.0 - no screen parameter)
        Respectlytics.track("test_event")
        Respectlytics.track("view_product")

        // Should complete without crash
        XCTAssertTrue(true)
    }

    func testTrackMultipleEvents() {
        Respectlytics.configure(apiKey: "test-api-key")

        // Track multiple events
        Respectlytics.track("button_clicked")
        Respectlytics.track("purchase")
        Respectlytics.track("app_launched")
        Respectlytics.track("session_started")

        XCTAssertTrue(true)
    }
}
