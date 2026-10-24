//
//  Respectlytics.swift
//  RespectlyticsSwift
//
//  Official Respectlytics SDK for iOS/macOS
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation

/// Main entry point for the Respectlytics SDK.
///
/// Usage:
/// ```swift
/// // 1. Configure at app launch
/// Respectlytics.configure(apiKey: "your-api-key")
///
/// // 2. Track events
/// Respectlytics.track("purchase")
///
/// // 3. Optionally with properties declared in the app's Settings
/// Respectlytics.track("paywall_viewed", properties: ["paywall": "b"])
/// ```
///
/// ## 🔄 Automatic Session Management
///
/// Session IDs are managed entirely by the SDK - no configuration needed:
/// - **New session on app launch**: Every time your app starts, a fresh session begins
/// - **2-hour rotation**: Sessions automatically rotate after 2 hours of use
/// - **RAM-only storage**: Session IDs are never written to disk
/// - **No cross-session tracking**: Each session is independent
public final class Respectlytics {

    // MARK: - Singleton

    private static let shared = Respectlytics()

    // MARK: - Private Properties

    private var configuration: Configuration?
    private let sessionManager = SessionManager()
    let eventQueue: EventQueue
    private let networkClient: NetworkClient

    private let queue = DispatchQueue(label: "com.respectlytics.sdk", qos: .utility)

    // MARK: - Initialization

    private convenience init() {
        self.init(networkClient: NetworkClient())
    }

    /// The SDK on a given network client. The public API uses `shared`; tests build
    /// their own instance to see what reaches the network.
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
        self.eventQueue = EventQueue(networkClient: networkClient)
    }

    // MARK: - Public API

    /// Initialize the SDK with your API key.
    /// Call once at app launch, typically in `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - Parameters:
    ///   - apiKey: Your Respectlytics API key from the dashboard
    ///   - apiEndpoint: Custom API endpoint URL for self-hosted instances (defaults to Respectlytics Cloud)
    public static func configure(apiKey: String, apiEndpoint: URL? = nil) {
        shared.setUp(apiKey: apiKey, apiEndpoint: apiEndpoint)
    }

    /// Track an event.
    ///
    /// The SDK automatically collects only privacy-safe metadata:
    /// - timestamp, session_id, platform
    ///
    /// Country is derived server-side from IP (which is immediately discarded).
    ///
    /// - Parameter eventName: Name of the event (e.g., "purchase", "button_clicked")
    public static func track(_ eventName: String) {
        shared.record(eventName, .empty)
    }

    /// Track an event with properties, such as the variant of an A/B test.
    ///
    /// ```swift
    /// Respectlytics.track("paywall_viewed", properties: ["paywall": "b"])
    /// Respectlytics.track("checkout_started", properties: ["price": 7.5])
    /// ```
    ///
    /// The server keeps a property only on a paid plan, once it is declared in the
    /// app's Settings on respectlytics.com: a list of values, or a number kept as
    /// the band it falls in. Everything else is dropped by the server.
    ///
    /// Before sending, the SDK drops what the server could never keep:
    /// - a name that is not `^[a-z][a-z0-9_]{0,39}$`
    /// - text that is not `^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,39}$`
    /// - a number that is NaN or infinite
    /// - any value that is not text, a number or a boolean (`nil` included)
    /// - properties beyond the first 20 that passed (by name, alphabetically)
    ///
    /// A dropped property never stops the event: it is sent with what passed. In
    /// debug builds the console names each dropped property and why, never its value.
    ///
    /// - Parameters:
    ///   - eventName: Name of the event (e.g., "purchase", "button_clicked")
    ///   - properties: Property names and values: `String`, any integer or
    ///     floating-point number, `Decimal`, or `Bool`
    public static func track(_ eventName: String, properties: [String: Any]) {
        // Filtered here, on the caller's thread, so only plain values cross to the SDK's queue.
        shared.record(eventName, PropertyFilter.filter(properties))
    }

    /// Force send all queued events immediately.
    /// Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.
    public static func flush() {
        shared.flushQueue()
    }

    // MARK: - Instance Implementation

    func setUp(apiKey: String, apiEndpoint: URL? = nil) {
        queue.async {
            guard !apiKey.isEmpty else {
                print("[Respectlytics] ⚠️ API key cannot be empty")
                return
            }

            self.configuration = Configuration(apiKey: apiKey, apiEndpoint: apiEndpoint ?? URL(string: "https://respectlytics.com/api/v1/events/")!)
            self.networkClient.configure(apiKey: apiKey, apiEndpoint: apiEndpoint)
            self.eventQueue.start()

            print("[Respectlytics] ✓ SDK configured (session-based analytics)")
        }
    }

    func record(_ eventName: String, _ properties: PropertyFilter.Filtered) {
        queue.async {
            guard self.configuration != nil else {
                print("[Respectlytics] ⚠️ SDK not configured. Call configure(apiKey:) first.")
                return
            }

            guard !eventName.isEmpty else {
                print("[Respectlytics] ⚠️ Event name cannot be empty")
                return
            }

            guard eventName.count <= 100 else {
                print("[Respectlytics] ⚠️ Event name too long (max 100 characters)")
                return
            }

            #if DEBUG
            if !properties.dropped.isEmpty {
                print(PropertyFilter.logLine(eventName: eventName, dropped: properties.dropped))
            }
            #endif

            let event = Event(
                eventName: eventName,
                sessionId: self.sessionManager.getSessionId(),
                properties: properties.kept
            )

            self.eventQueue.add(event)
        }
    }

    func flushQueue() {
        queue.async {
            self.eventQueue.flush()
        }
    }
}
