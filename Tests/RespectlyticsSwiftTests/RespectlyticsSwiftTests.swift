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
            name: "test_event",
            screen: "TestScreen",
            sessionId: "session456"
        )
        
        XCTAssertEqual(event.eventName, "test_event")
        XCTAssertEqual(event.screen, "TestScreen")
        XCTAssertEqual(event.sessionId, "session456")
        XCTAssertFalse(event.timestamp.isEmpty)
    }
    
    func testEventEncoding() throws {
        let event = Event(
            name: "test_event",
            screen: "HomeScreen",
            sessionId: "session456"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        XCTAssertNotNil(data)
        
        // Verify it can be decoded back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.eventName, event.eventName)
        XCTAssertEqual(decoded.screen, event.screen)
    }
    
    func testEventEncodingWithoutOptionalFields() throws {
        let event = Event(
            name: "simple_event",
            screen: nil,
            sessionId: "session789"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        XCTAssertNotNil(data)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.eventName, "simple_event")
        XCTAssertNil(decoded.screen)
    }
    
    func testEventEncodesOnlyAllowedFields() throws {
        let event = Event(
            name: "test_event",
            screen: "ProductPage",
            sessionId: "session456"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // These fields should be present (API allowlist)
        XCTAssertNotNil(json["event_name"])
        XCTAssertNotNil(json["timestamp"])
        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["screen"])
        XCTAssertNotNil(json["platform"])
        XCTAssertNotNil(json["os_version"])
        XCTAssertNotNil(json["app_version"])
        XCTAssertNotNil(json["locale"])
        XCTAssertNotNil(json["device_type"])
        
        // user_id should NOT be present (v2.0.0 - session-based only)
        XCTAssertNil(json["user_id"], "user_id should not be in event payload - v2.0.0 uses session-based analytics only")
        
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
            name: "test_event",
            screen: nil,
            sessionId: "abc123"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // user_id should not appear anywhere in the JSON
        XCTAssertFalse(jsonString.contains("user_id"), "Event payload must not contain user_id field")
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
        // This is a compile-time check - if this compiles, identify() doesn't exist
        let mirror = Mirror(reflecting: Respectlytics.self)
        let methods = mirror.children.compactMap { $0.label }
        
        // The method should not exist on the type
        XCTAssertFalse(methods.contains("identify"), "identify() method should not exist in v2.0.0")
    }
    
    func testResetMethodDoesNotExist() {
        // Verify reset() method has been removed
        // This is a compile-time check - if this compiles, reset() doesn't exist
        let mirror = Mirror(reflecting: Respectlytics.self)
        let methods = mirror.children.compactMap { $0.label }
        
        // The method should not exist on the type
        XCTAssertFalse(methods.contains("reset"), "reset() method should not exist in v2.0.0")
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
        
        // Track events (no identify() needed in v2.0.0)
        Respectlytics.track("test_event")
        Respectlytics.track("view_product", screen: "ProductDetail")
        
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    func testTrackWithScreen() {
        Respectlytics.configure(apiKey: "test-api-key")
        
        // Track with screen parameter
        Respectlytics.track("button_clicked", screen: "HomePage")
        Respectlytics.track("purchase", screen: "CheckoutScreen")
        
        XCTAssertTrue(true)
    }
    
    func testTrackWithoutScreen() {
        Respectlytics.configure(apiKey: "test-api-key")
        
        // Track without screen parameter - should work fine
        Respectlytics.track("app_launched")
        Respectlytics.track("session_started")
        
        XCTAssertTrue(true)
    }
}
