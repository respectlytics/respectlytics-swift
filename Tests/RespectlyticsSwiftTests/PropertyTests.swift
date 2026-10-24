//
//  PropertyTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//
//  Event properties (3.1.0): the on-device filter, the JSON body, and that a
//  bad property never stops the event.
//

import XCTest
import CoreGraphics
@testable import RespectlyticsSwift

final class PropertyTests: XCTestCase {

    // MARK: - Filter: what is kept

    func testKeepsEveryKindOfValueTheServerCanKeep() {
        let filtered = PropertyFilter.filter([
            "paywall": "b",
            "price": 7.5,
            "count": 3,
            "trial": true,
            "plan": "Pro Plan v1.2-beta_3",
        ])

        XCTAssertEqual(filtered.dropped, [])
        XCTAssertEqual(filtered.kept, [
            "paywall": .string("b"),
            "price": .double(7.5),
            "count": .int(3),
            "trial": .bool(true),
            "plan": .string("Pro Plan v1.2-beta_3"),
        ])
    }

    func testEmptyPropertiesKeepNothingAndDropNothing() {
        XCTAssertEqual(PropertyFilter.filter([:]), .empty)
    }

    // MARK: - Filter: the name rule ^[a-z][a-z0-9_]{0,39}$

    func testNameRuleAcceptsWhatTheServerAccepts() {
        let longest = "a" + String(repeating: "b", count: 39)
        for name in ["a", "paywall", "plan_2", "a_1_b", longest] {
            XCTAssertTrue(PropertyFilter.isValidName(name), "\(name) should be a valid name")
            XCTAssertEqual(PropertyFilter.filter([name: "b"]).kept, [name: .string("b")])
        }
    }

    func testNameRuleDropsEverythingElse() {
        let tooLong = "a" + String(repeating: "b", count: 40)
        let names = ["", "Paywall", "payWall", "1st", "_x", "pay-wall", "pay wall", "pay.wall",
                     "café", "e\u{301}", "email@example", "a\n", tooLong]
        for name in names {
            XCTAssertFalse(PropertyFilter.isValidName(name), "\(name) should be an invalid name")
            let filtered = PropertyFilter.filter([name: "b"])
            XCTAssertEqual(filtered.kept, [:], "\(name) should be dropped")
            XCTAssertEqual(filtered.dropped, [PropertyFilter.Dropped(name: name, reason: .invalidName)])
        }
    }

    // MARK: - Filter: the text rule ^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,39}$

    func testTextRuleAcceptsWhatTheServerAccepts() {
        let longest = "A" + String(repeating: "z", count: 39)
        for text in ["b", "B", "7", "A1", "Pro Plan", "v1.2-beta_3", "true", longest] {
            XCTAssertTrue(PropertyFilter.isValidText(text), "\(text) should be valid text")
            XCTAssertEqual(PropertyFilter.filter(["variant": text]).kept, ["variant": .string(text)])
        }
    }

    func testTextRuleDropsFreeText() {
        let tooLong = "A" + String(repeating: "z", count: 40)
        let texts = ["", " b", "-b", "_b", ".b", "john@example.com", "a/b", "hello, world",
                     "naïve", "b\n", "tab\there", "100%", tooLong]
        for text in texts {
            XCTAssertFalse(PropertyFilter.isValidText(text), "\(text) should be invalid text")
            let filtered = PropertyFilter.filter(["variant": text])
            XCTAssertEqual(filtered.kept, [:], "\(text) should be dropped")
            XCTAssertEqual(filtered.dropped, [PropertyFilter.Dropped(name: "variant", reason: .invalidValue)])
        }
    }

    func testSubstringIsText() {
        let text = "b, c"
        let filtered = PropertyFilter.filter(["variant": text.prefix(1)])
        XCTAssertEqual(filtered.kept, ["variant": .string("b")])
    }

    // MARK: - Filter: numbers

    func testKeepsFiniteNumbersOfEveryType() {
        let filtered = PropertyFilter.filter([
            "int": 3,
            "negative": -12,
            "int8": Int8(8),
            "uint32": UInt32(32),
            "huge": UInt64.max,
            "float": Float(2.5),
            "double": 7.5,
            "cgfloat": CGFloat(1.5),
            "decimal": Decimal(string: "9.99")!,
            "nsnumber": NSNumber(value: 42),
            "nsdouble": NSNumber(value: 0.25),
            "nsdecimal": NSDecimalNumber(string: "4.5"),
        ])

        XCTAssertEqual(filtered.dropped, [])
        XCTAssertEqual(filtered.kept["int"], .int(3))
        XCTAssertEqual(filtered.kept["negative"], .int(-12))
        XCTAssertEqual(filtered.kept["int8"], .int(8))
        XCTAssertEqual(filtered.kept["uint32"], .int(32))
        XCTAssertEqual(filtered.kept["huge"], .double(Double(UInt64.max)))
        XCTAssertEqual(filtered.kept["float"], .double(2.5))
        XCTAssertEqual(filtered.kept["double"], .double(7.5))
        XCTAssertEqual(filtered.kept["cgfloat"], .double(1.5))
        XCTAssertEqual(filtered.kept["decimal"], .double(9.99))
        XCTAssertEqual(filtered.kept["nsnumber"], .int(42))
        XCTAssertEqual(filtered.kept["nsdouble"], .double(0.25))
        XCTAssertEqual(filtered.kept["nsdecimal"], .double(4.5))
    }

    func testDropsNaNAndInfinity() {
        let filtered = PropertyFilter.filter([
            "nan": Double.nan,
            "inf": Double.infinity,
            "neg_inf": -Double.infinity,
            "float_nan": Float.nan,
            "decimal_nan": Decimal.nan,
            "ns_nan": NSNumber(value: Double.nan),
            "ns_inf": NSNumber(value: Double.infinity),
        ])

        XCTAssertEqual(filtered.kept, [:])
        XCTAssertEqual(filtered.dropped.map(\.name), ["decimal_nan", "float_nan", "inf", "nan", "neg_inf", "ns_inf", "ns_nan"])
        XCTAssertTrue(filtered.dropped.allSatisfy { $0.reason == .notFinite })
    }

    // MARK: - Filter: booleans

    func testKeepsBooleansAsBooleans() {
        let json = try! JSONSerialization.jsonObject(with: Data("[true, 1]".utf8)) as! [Any]
        let filtered = PropertyFilter.filter([
            "swift_true": true,
            "swift_false": false,
            "ns_bool": NSNumber(value: true),
            "json_bool": json[0],
            "json_one": json[1],
            "ns_one": NSNumber(value: 1),
        ])

        XCTAssertEqual(filtered.dropped, [])
        XCTAssertEqual(filtered.kept["swift_true"], .bool(true))
        XCTAssertEqual(filtered.kept["swift_false"], .bool(false))
        XCTAssertEqual(filtered.kept["ns_bool"], .bool(true))
        XCTAssertEqual(filtered.kept["json_bool"], .bool(true))
        // An NSNumber holding 1 casts to Bool in Swift, but it is a number.
        XCTAssertEqual(filtered.kept["json_one"], .int(1))
        XCTAssertEqual(filtered.kept["ns_one"], .int(1))
    }

    // MARK: - Filter: wrong types

    func testDropsEveryOtherType() {
        let nothing: String? = nil
        let filtered = PropertyFilter.filter([
            "date": Date(),
            "array": ["b"],
            "dictionary": ["a": "b"],
            "url": URL(string: "https://example.com")!,
            "data": Data([1, 2]),
            "null": NSNull(),
            "nil": nothing as Any,
            "character": Character("b"),
        ])

        XCTAssertEqual(filtered.kept, [:])
        XCTAssertEqual(filtered.dropped.map(\.name), ["array", "character", "data", "date", "dictionary", "nil", "null", "url"])
        XCTAssertTrue(filtered.dropped.allSatisfy { $0.reason == .unsupportedType })
    }

    func testOptionalValuesAreUnwrapped() {
        let variant: String? = "b"
        let price: Double?? = 7.5
        let filtered = PropertyFilter.filter(["variant": variant as Any, "price": price as Any])

        XCTAssertEqual(filtered.dropped, [])
        XCTAssertEqual(filtered.kept, ["variant": .string("b"), "price": .double(7.5)])
    }

    // MARK: - Filter: at most 20

    func testKeepsAtMostTwentyFirstByName() {
        var properties: [String: Any] = [:]
        for i in 0..<25 {
            properties[String(format: "p%02d", i)] = i
        }

        let filtered = PropertyFilter.filter(properties)

        XCTAssertEqual(filtered.kept.count, 20)
        XCTAssertEqual(filtered.kept.keys.sorted(), (0..<20).map { String(format: "p%02d", $0) })
        XCTAssertEqual(filtered.dropped.map(\.name), (20..<25).map { String(format: "p%02d", $0) })
        XCTAssertTrue(filtered.dropped.allSatisfy { $0.reason == .overLimit })
        XCTAssertTrue(PropertyFilter.logLine(eventName: "e", dropped: filtered.dropped).contains("p20 (more than 20)"))
    }

    func testDroppedPropertiesDoNotCountTowardsTheLimit() {
        var properties: [String: Any] = ["Bad": "b", "email": "john@example.com", "nan": Double.nan]
        for i in 0..<20 {
            properties[String(format: "p%02d", i)] = "b"
        }

        let filtered = PropertyFilter.filter(properties)

        XCTAssertEqual(filtered.kept.count, 20)
        XCTAssertEqual(filtered.dropped.map(\.name), ["Bad", "email", "nan"])
    }

    // MARK: - Debug log

    func testLogLineNamesEachDroppedPropertyButNoValue() {
        let filtered = PropertyFilter.filter([
            "Email": "b",
            "note": "john@example.com",
            "ratio": Double.nan,
            "when": Date(),
            "paywall": "b",
        ])

        let line = PropertyFilter.logLine(eventName: "paywall_viewed", dropped: filtered.dropped)

        XCTAssertTrue(line.hasPrefix("[Respectlytics]"))
        XCTAssertFalse(line.contains("\n"), "one line per event")
        XCTAssertTrue(line.contains("\"paywall_viewed\" was sent without 4 properties"))
        XCTAssertTrue(line.contains("Email (invalid name)"))
        XCTAssertTrue(line.contains("note (invalid value)"))
        XCTAssertTrue(line.contains("ratio (number not finite)"))
        XCTAssertTrue(line.contains("when (unsupported type)"))
        XCTAssertFalse(line.contains("john@example.com"), "the log must never carry a value")
        XCTAssertFalse(line.contains("paywall "), "a kept property is not named")
        XCTAssertFalse(line.contains("—") || line.contains("–"))
    }

    func testLogLineCutsLongNames() {
        let name = "Not_A_Valid_Name_" + String(repeating: "x", count: 100)
        let line = PropertyFilter.logLine(eventName: "e", dropped: PropertyFilter.filter([name: "b"]).dropped)
        XCTAssertTrue(line.contains(String(name.prefix(40)) + " ("))
        XCTAssertFalse(line.contains(String(name.prefix(41))))
    }

    // MARK: - JSON body

    func testBodyWithoutPropertiesHasNoPropertiesKey() throws {
        for event in [
            Event(eventName: "purchase", sessionId: "abc123"),
            Event(eventName: "purchase", sessionId: "abc123", properties: [:]),
            Event(eventName: "purchase", sessionId: "abc123", properties: PropertyFilter.filter(["Bad": "b"]).kept),
        ] {
            let json = try body(of: event)
            XCTAssertEqual(Set(json.keys), ["event_name", "timestamp", "session_id", "platform"])
        }
    }

    func testBodyCarriesTheFilteredProperties() throws {
        let filtered = PropertyFilter.filter([
            "paywall": "b",
            "price": 7.5,
            "count": 3,
            "trial": true,
            "Email": "b",
            "note": "john@example.com",
            "ratio": Double.infinity,
            "when": Date(),
        ])
        let event = Event(eventName: "paywall_viewed", sessionId: "abc123", properties: filtered.kept)

        let request = try client().request(for: event, apiKey: "test-key")
        let data = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let properties = try XCTUnwrap(json["properties"] as? [String: Any])

        XCTAssertEqual(Set(json.keys), ["event_name", "timestamp", "session_id", "platform", "properties"])
        XCTAssertEqual(Set(properties.keys), ["paywall", "price", "count", "trial"])
        XCTAssertEqual(properties["paywall"] as? String, "b")
        XCTAssertEqual(properties["price"] as? Double, 7.5)
        XCTAssertEqual(properties["count"] as? Int, 3)
        XCTAssertEqual(properties["trial"] as? Bool, true)

        // JSON types the server reads: an integer, a fraction and a real boolean.
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"count\":3"), text)
        XCTAssertTrue(text.contains("\"price\":7.5"), text)
        XCTAssertTrue(text.contains("\"trial\":true"), text)
        for dropped in ["Email", "note", "john@example.com", "ratio", "when"] {
            XCTAssertFalse(text.contains(dropped), "\(dropped) must not leave the device")
        }
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Key"), "test-key")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testEventWithPropertiesRoundTrips() throws {
        let event = Event(eventName: "paywall_viewed", sessionId: "abc123",
                          properties: ["paywall": .string("b"), "price": .double(7.5), "count": .int(3), "trial": .bool(true)])
        let decoded = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(decoded.properties, event.properties)
    }

    // MARK: - A bad property never stops the event

    func testBadPropertiesNeverStopTheEvent() throws {
        let bodies = try sendThroughTheSDK([
            ("paywall_viewed", ["paywall": "b", "Email": "b", "note": "john@example.com", "ratio": Double.nan, "when": Date()]),
            ("checkout_started", ["Bad Name": "b", "email": "john@example.com", "nan": Double.nan, "nil": Optional<String>.none as Any]),
        ])

        XCTAssertEqual(bodies.count, 2, "both events are sent")
        let first = try XCTUnwrap(bodies.first { $0["event_name"] as? String == "paywall_viewed" })
        XCTAssertEqual(first["properties"] as? [String: String], ["paywall": "b"])

        // Every property dropped: the event still goes, exactly as an event without properties.
        let second = try XCTUnwrap(bodies.first { $0["event_name"] as? String == "checkout_started" })
        XCTAssertNil(second["properties"])
        XCTAssertEqual(Set(second.keys), ["event_name", "timestamp", "session_id", "platform"])
    }

    func testEventWithoutPropertiesIsSentAsBefore() throws {
        let bodies = try sendThroughTheSDK([("purchase", nil)])

        XCTAssertEqual(bodies.count, 1)
        XCTAssertEqual(Set(bodies[0].keys), ["event_name", "timestamp", "session_id", "platform"])
    }

    // MARK: - Public API

    func testPublicAPIStaysSourceCompatible() {
        // Existing calls and function references to track(_:) still compile.
        let trackName: (String) -> Void = Respectlytics.track
        let trackWithProperties: (String, [String: Any]) -> Void = Respectlytics.track(_:properties:)
        XCTAssertNotNil(trackName as Any)
        XCTAssertNotNil(trackWithProperties as Any)

        Respectlytics.configure(apiKey: "test-api-key")
        Respectlytics.track("purchase")
        Respectlytics.track("paywall_viewed", properties: ["paywall": "b", "price": 7.5, "trial": true, "Bad": Date()])
    }

    // MARK: - Helpers

    private let stubEndpoint = URL(string: "https://stub.respectlytics.invalid/api/v1/events/")!

    private func client() -> NetworkClient {
        let client = NetworkClient()
        client.configure(apiKey: "test-key", apiEndpoint: stubEndpoint)
        return client
    }

    private func body(of event: Event) throws -> [String: Any] {
        let data = try XCTUnwrap(try client().request(for: event, apiKey: "test-key").httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Track each event through an SDK instance whose network goes to a stub,
    /// flush, and return the JSON bodies that reached the network.
    private func sendThroughTheSDK(_ events: [(String, [String: Any]?)]) throws -> [[String: Any]] {
        let received = expectation(description: "events reach the network")
        received.expectedFulfillmentCount = events.count
        StubURLProtocol.start { _ in received.fulfill() }
        defer { StubURLProtocol.stop() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let sdk = Respectlytics(networkClient: NetworkClient(session: URLSession(configuration: configuration)))

        sdk.setUp(apiKey: "test-key", apiEndpoint: stubEndpoint)
        for (name, properties) in events {
            // The same two steps as the public track(_:) and track(_:properties:).
            sdk.record(name, properties.map(PropertyFilter.filter) ?? .empty)
        }
        sdk.flushQueue()

        wait(for: [received], timeout: 10)
        return try StubURLProtocol.bodies().map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any])
        }
    }
}

/// Answers every request with 201 and keeps its body, so a test sees what the SDK sent.
final class StubURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var received: [Data] = []
    private static var onReceive: ((Data) -> Void)?

    static func start(onReceive handler: @escaping (Data) -> Void) {
        lock.lock()
        received = []
        onReceive = handler
        lock.unlock()
    }

    static func stop() {
        lock.lock()
        onReceive = nil
        lock.unlock()
    }

    static func bodies() -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? Self.read(request.httpBodyStream)

        Self.lock.lock()
        Self.received.append(body)
        let handler = Self.onReceive
        Self.lock.unlock()

        let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
        handler?(body)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream?) -> Data {
        guard let stream = stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
