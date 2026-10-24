//
//  EventQueueTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//
//  Sending (3.1.1): an event the server accepted is never sent twice, and an
//  event it refuses (400) never holds up the events behind it.
//

import XCTest
@testable import RespectlyticsSwift

final class EventQueueTests: XCTestCase {

    private let endpoint = URL(string: "https://stub.respectlytics.invalid/api/v1/events/")!

    override func tearDown() {
        StubURLProtocol.stop()
        super.tearDown()
    }

    // MARK: - Already-sent events are not resent

    func testFailureRequeuesOnlyTheEventsNotYetSent() async throws {
        // "b" fails with a 500, which is worth trying again later
        StubURLProtocol.start(status: { $0["event_name"] as? String == "b" ? 500 : 201 })
        let queue = makeQueue()
        queue.add(event("a"))
        queue.add(event("b"))
        queue.add(event("c"))

        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["a", "b"], "sending stops at the failure")
        XCTAssertEqual(queue.queuedEvents.map(\.eventName), ["b", "c"], "only the unsent events wait")

        StubURLProtocol.start()
        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["b", "c"], "the next flush sends what waited, and never a again")
        XCTAssertTrue(queue.queuedEvents.isEmpty)
    }

    func testUnauthorizedIsStillKeptForLater() async throws {
        StubURLProtocol.start(status: { _ in 401 })
        let queue = makeQueue()
        queue.add(event("a"))

        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["a"])
        XCTAssertEqual(queue.queuedEvents.map(\.eventName), ["a"], "401 is kept for a later flush, as before")
    }

    // MARK: - A 400 is final

    func testRefusedEventIsDroppedAndLaterEventsStillSent() async throws {
        StubURLProtocol.start(status: { $0["event_name"] as? String == "a" ? 400 : 201 })
        let queue = makeQueue()
        queue.add(event("a"))
        queue.add(event("b"))

        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["a", "b"], "an event without properties is tried once, then the next is sent")
        XCTAssertTrue(queue.queuedEvents.isEmpty, "the refused event is dropped, not requeued")
    }

    func testRefusedPropertiesAreDroppedAndTheEventIsSentWithoutThem() async throws {
        // A server older than 3.1.0 answers 400 to any body with properties
        StubURLProtocol.start(status: { $0["properties"] == nil ? 201 : 400 })
        let queue = makeQueue()
        let original = event("paywall_viewed", properties: ["paywall": .string("b")])
        queue.add(original)
        queue.add(event("after"))

        await queue.flush()?.value

        let bodies = try sentBodies()
        XCTAssertEqual(bodies.map { $0["event_name"] as? String }, ["paywall_viewed", "paywall_viewed", "after"])
        XCTAssertEqual(bodies[0]["properties"] as? [String: String], ["paywall": "b"])
        XCTAssertEqual(Set(bodies[1].keys), ["event_name", "timestamp", "session_id", "platform"])
        XCTAssertEqual(bodies[1]["timestamp"] as? String, original.timestamp, "the same event, only without properties")
        XCTAssertEqual(bodies[1]["session_id"] as? String, original.sessionId)
        XCTAssertTrue(queue.queuedEvents.isEmpty)
    }

    func testEventRefusedWithAndWithoutPropertiesIsDropped() async throws {
        StubURLProtocol.start(status: { $0["event_name"] as? String == "bad" ? 400 : 201 })
        let queue = makeQueue()
        queue.add(event("bad", properties: ["paywall": .string("b")]))
        queue.add(event("after"))

        await queue.flush()?.value

        let bodies = try sentBodies()
        XCTAssertEqual(bodies.map { $0["event_name"] as? String }, ["bad", "bad", "after"],
                       "tried with and without properties, once each, then the next event is sent")
        XCTAssertNotNil(bodies[0]["properties"])
        XCTAssertNil(bodies[1]["properties"])
        XCTAssertTrue(queue.queuedEvents.isEmpty, "the refused event never holds up the queue")
    }

    // MARK: - Helpers

    private func makeQueue() -> EventQueue {
        let client = NetworkClient(session: StubURLProtocol.session())
        client.configure(apiKey: "test-key", apiEndpoint: endpoint)
        return EventQueue(networkClient: client)
    }

    private func event(_ name: String, properties: [String: PropertyValue] = [:]) -> Event {
        Event(eventName: name, sessionId: "abc123", properties: properties)
    }

    private func sentBodies() throws -> [[String: Any]] {
        try StubURLProtocol.bodies().map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any])
        }
    }

    private func sentNames() -> [String] {
        ((try? sentBodies()) ?? []).compactMap { $0["event_name"] as? String }
    }
}
