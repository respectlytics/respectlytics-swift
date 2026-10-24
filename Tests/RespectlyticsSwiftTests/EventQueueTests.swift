//
//  EventQueueTests.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//
//  Sending (3.1.1): an event the server accepted is never sent twice, and an
//  event it refuses (400) never holds up the events behind it.
//  3.1.2: a refused app key (401) stops sending until configure is called again.
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

    // MARK: - A 401 stops sending for the run

    func testUnauthorizedMeansExactlyOneRequest() async throws {
        StubURLProtocol.start(status: { _ in 401 })
        let queue = makeQueue()
        queue.add(event("a"))
        queue.add(event("b"))
        queue.add(event("c"))

        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["a"], "one 401 is one request: never retried, nothing after it sent")
        XCTAssertTrue(queue.isRefused)
        XCTAssertTrue(queue.queuedEvents.isEmpty, "the queued events are dropped")

        // Later tracks are ignored and later flushes send nothing
        queue.add(event("d"))
        XCTAssertTrue(queue.queuedEvents.isEmpty)
        XCTAssertNil(queue.flush())
        XCTAssertEqual(sentNames(), ["a"])
    }

    func testUnauthorizedRetryWithoutPropertiesIsNotAttempted() async throws {
        StubURLProtocol.start(status: { _ in 401 })
        let queue = makeQueue()
        queue.add(event("a", properties: ["paywall": .string("b")]))

        await queue.flush()?.value

        XCTAssertEqual(sentNames(), ["a"], "only a 400 is sent again without properties")
        XCTAssertTrue(queue.isRefused)
    }

    func testStartAgainResumesSending() async throws {
        StubURLProtocol.start(status: { _ in 401 })
        let queue = makeQueue()
        queue.add(event("a"))
        await queue.flush()?.value
        XCTAssertTrue(queue.isRefused)

        StubURLProtocol.start()
        queue.start()
        queue.add(event("b"))
        await queue.flush()?.value

        XCTAssertFalse(queue.isRefused)
        XCTAssertEqual(sentNames(), ["b"])
        XCTAssertTrue(queue.queuedEvents.isEmpty)
    }

    func testConfigureAgainResetsAfterUnauthorized() throws {
        // Through the SDK itself: track, a 401, more tracks, then configure again
        let first = expectation(description: "the first event reaches the server")
        let last = expectation(description: "the event after configure reaches the server")
        StubURLProtocol.start(
            status: { $0["event_name"] as? String == "a" ? 401 : 201 },
            onReceive: { body in
                let name = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["event_name"] as? String
                if name == "a" { first.fulfill() }
                if name == "c" { last.fulfill() }
            }
        )
        let sdk = Respectlytics(networkClient: NetworkClient(session: StubURLProtocol.session()))

        sdk.setUp(apiKey: "wrong-key", apiEndpoint: endpoint)
        sdk.record("a", .empty)
        sdk.flushQueue()
        wait(for: [first], timeout: 10)
        let refused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in sdk.eventQueue.isRefused }, object: nil)
        wait(for: [refused], timeout: 10)

        sdk.record("b", .empty)  // ignored: tracked after the 401
        sdk.flushQueue()
        sdk.setUp(apiKey: "right-key", apiEndpoint: endpoint)
        sdk.record("c", .empty)
        sdk.flushQueue()
        wait(for: [last], timeout: 10)

        // The SDK's queue is serial, so "b" would have reached the server before "c"
        XCTAssertEqual(sentNames(), ["a", "c"])
        XCTAssertFalse(sdk.eventQueue.isRefused)
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
