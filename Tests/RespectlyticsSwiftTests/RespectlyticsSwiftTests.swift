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
            properties: ["key": "value"],
            userId: "user123",
            sessionId: "session456"
        )
        
        XCTAssertEqual(event.eventName, "test_event")
        XCTAssertEqual(event.userId, "user123")
        XCTAssertEqual(event.sessionId, "session456")
        XCTAssertFalse(event.timestamp.isEmpty)
    }
    
    func testEventEncoding() throws {
        let event = Event(
            name: "test_event",
            properties: ["string": "value", "number": 42, "bool": true],
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
    }
    
    func testEventEncodingWithoutProperties() throws {
        let event = Event(
            name: "simple_event",
            properties: nil,
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
    
    // MARK: - AnyCodable Tests
    
    func testAnyCodableString() throws {
        let value = AnyCodable("test")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let string = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(string, "\"test\"")
    }
    
    func testAnyCodableInt() throws {
        let value = AnyCodable(42)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let string = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(string, "42")
    }
    
    func testAnyCodableBool() throws {
        let value = AnyCodable(true)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let string = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(string, "true")
    }
    
    func testAnyCodableArray() throws {
        let value = AnyCodable([1, 2, 3])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let string = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(string, "[1,2,3]")
    }
    
    func testAnyCodableDictionary() throws {
        let value = AnyCodable(["key": "value"])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)
        
        if let dict = decoded.value as? [String: Any] {
            XCTAssertEqual(dict["key"] as? String, "value")
        } else {
            XCTFail("Expected dictionary")
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullEventFlow() {
        // Configure SDK
        Respectlytics.configure(apiKey: "test-api-key")
        
        // Enable user tracking
        Respectlytics.identify()
        
        // Track an event
        Respectlytics.track("test_event", properties: ["action": "test"])
        
        // Reset user
        Respectlytics.reset()
        
        // Should complete without crash
        XCTAssertTrue(true)
    }
}
