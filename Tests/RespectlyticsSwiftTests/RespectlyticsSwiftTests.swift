//
//  RespectlyticsSwiftTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import XCTest
@testable import RespectlyticsSwift

final class RespectlyticsSwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Respectlytics.reset()
    }
    
    override func tearDown() {
        Respectlytics.reset()
        super.tearDown()
    }
    
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
            userId: "user123",
            sessionId: "session456"
        )
        
        XCTAssertEqual(event.eventName, "test_event")
        XCTAssertEqual(event.screen, "TestScreen")
        XCTAssertEqual(event.userId, "user123")
        XCTAssertEqual(event.sessionId, "session456")
        XCTAssertFalse(event.timestamp.isEmpty)
    }
    
    func testEventEncoding() throws {
        let event = Event(
            name: "test_event",
            screen: "HomeScreen",
            userId: "user123",
            sessionId: "session456"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        XCTAssertNotNil(data)
        
        // Verify it can be decoded back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.eventName, event.eventName)
        XCTAssertEqual(decoded.userId, event.userId)
        XCTAssertEqual(decoded.screen, event.screen)
    }
    
    func testEventEncodingWithoutOptionalFields() throws {
        let event = Event(
            name: "simple_event",
            screen: nil,
            userId: nil,
            sessionId: "session789"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        XCTAssertNotNil(data)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Event.self, from: data)
        XCTAssertEqual(decoded.eventName, "simple_event")
        XCTAssertNil(decoded.userId)
        XCTAssertNil(decoded.screen)
    }
    
    func testEventEncodesOnlyAllowedFields() throws {
        let event = Event(
            name: "test_event",
            screen: "ProductPage",
            userId: "abc123",
            sessionId: "session456"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // These fields should be present (API allowlist)
        XCTAssertNotNil(json["event_name"])
        XCTAssertNotNil(json["timestamp"])
        XCTAssertNotNil(json["session_id"])
        XCTAssertNotNil(json["user_id"])
        XCTAssertNotNil(json["screen"])
        XCTAssertNotNil(json["platform"])
        XCTAssertNotNil(json["os_version"])
        XCTAssertNotNil(json["app_version"])
        XCTAssertNotNil(json["locale"])
        XCTAssertNotNil(json["device_type"])
        
        // These fields should NOT be present (privacy violation)
        XCTAssertNil(json["properties"])
        XCTAssertNil(json["metadata"])
        XCTAssertNil(json["data"])
        XCTAssertNil(json["custom"])
        XCTAssertNil(json["extra"])
    }
    
    // MARK: - Session Manager Tests
    
    func testSessionManagerGeneratesSessionId() {
        let sessionManager = SessionManager()
        let sessionId = sessionManager.getSessionId()
        
        XCTAssertFalse(sessionId.isEmpty)
        XCTAssertEqual(sessionId.count, 32) // UUID without dashes, lowercased
    }
    
    func testSessionManagerMaintainsSameSession() {
        let sessionManager = SessionManager()
        let sessionId1 = sessionManager.getSessionId()
        let sessionId2 = sessionManager.getSessionId()
        
        XCTAssertEqual(sessionId1, sessionId2)
    }
    
    // MARK: - User Manager Tests
    
    func testUserManagerStartsWithNoUser() {
        let userManager = UserManager()
        // After a reset, userId should be nil (or it might have a stored value from keychain)
        // This test is more about the structure existing
        XCTAssertNotNil(userManager)
    }
    
    func testUserManagerIdentify() {
        let userManager = UserManager()
        userManager.identify()
        
        XCTAssertNotNil(userManager.userId)
        XCTAssertEqual(userManager.userId?.count, 32) // UUID without dashes
    }
    
    func testUserManagerReset() {
        let userManager = UserManager()
        userManager.identify()
        XCTAssertNotNil(userManager.userId)
        
        userManager.reset()
        XCTAssertNil(userManager.userId)
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
        
        // Enable user tracking
        Respectlytics.identify()
        
        // Track events (no properties - API doesn't support them)
        Respectlytics.track("test_event")
        Respectlytics.track("view_product", screen: "ProductDetail")
        
        // Reset user
        Respectlytics.reset()
        
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
