//
//  Respectlytics.swift
//  RespectlyticsSwift
//
//  Official Respectlytics SDK for iOS/macOS
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//
//  This SDK is provided under a proprietary license.
//  See LICENSE file for details.
//

import Foundation

/// Main entry point for the Respectlytics SDK.
/// 
/// Usage:
/// ```swift
/// // 1. Configure at app launch
/// Respectlytics.configure(apiKey: "your-api-key")
/// 
/// // 2. Enable user tracking (optional)
/// Respectlytics.identify()
/// 
/// // 3. Track events
/// Respectlytics.track("purchase", properties: ["plan": "pro"])
/// ```
public final class Respectlytics {
    
    // MARK: - Singleton
    
    private static let shared = Respectlytics()
    
    // MARK: - Private Properties
    
    private var configuration: Configuration?
    private let sessionManager = SessionManager()
    private let userManager = UserManager()
    private let eventQueue: EventQueue
    private let networkClient: NetworkClient
    
    private let queue = DispatchQueue(label: "com.respectlytics.sdk", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        self.networkClient = NetworkClient()
        self.eventQueue = EventQueue(networkClient: networkClient)
    }
    
    // MARK: - Public API
    
    /// Initialize the SDK with your API key.
    /// Call once at app launch, typically in `application(_:didFinishLaunchingWithOptions:)`.
    ///
    /// - Parameter apiKey: Your Respectlytics API key from the dashboard
    public static func configure(apiKey: String) {
        shared.queue.async {
            guard !apiKey.isEmpty else {
                print("[Respectlytics] ⚠️ API key cannot be empty")
                return
            }
            
            shared.configuration = Configuration(apiKey: apiKey)
            shared.networkClient.configure(apiKey: apiKey)
            shared.eventQueue.start()
            
            print("[Respectlytics] ✓ SDK configured")
        }
    }
    
    /// Track an event with optional properties.
    ///
    /// - Parameters:
    ///   - eventName: Name of the event (e.g., "purchase", "button_clicked")
    ///   - properties: Optional dictionary of additional properties
    public static func track(_ eventName: String, properties: [String: Any]? = nil) {
        shared.queue.async {
            guard shared.configuration != nil else {
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
            
            let event = Event(
                eventName: eventName,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                sessionId: shared.sessionManager.getSessionId(),
                userId: shared.userManager.userId,
                properties: properties,
                metadata: EventMetadata.current()
            )
            
            shared.eventQueue.add(event)
        }
    }
    
    /// Enable cross-session user tracking.
    /// Generates and persists a random user ID that will be included in all subsequent events.
    ///
    /// - Note: User IDs are auto-generated and cannot be overridden. This is by design for privacy.
    public static func identify() {
        shared.queue.async {
            shared.userManager.identify()
            print("[Respectlytics] ✓ User identified")
        }
    }
    
    /// Clear the user ID.
    /// Call when the user logs out. Subsequent events will be anonymous until `identify()` is called again.
    public static func reset() {
        shared.queue.async {
            shared.userManager.reset()
            print("[Respectlytics] ✓ User reset")
        }
    }
    
    /// Force send all queued events immediately.
    /// Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.
    public static func flush() {
        shared.queue.async {
            shared.eventQueue.flush()
        }
    }
}
