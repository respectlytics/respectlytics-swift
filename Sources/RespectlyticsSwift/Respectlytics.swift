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
/// // 2. Track events
/// Respectlytics.track("purchase")
/// Respectlytics.track("view_product", screen: "ProductDetail")
/// ```
///
/// ## 🔄 Automatic Session Management
///
/// Session IDs are managed entirely by the SDK - no configuration needed:
/// - **New session on app launch**: Every time your app starts, a fresh session begins
/// - **2-hour rotation**: Sessions automatically rotate after 2 hours of use
/// - **RAM-only storage**: Session IDs are never written to disk (GDPR/ePrivacy compliant)
/// - **No cross-session tracking**: Each session is independent and anonymous
public final class Respectlytics {
    
    // MARK: - Singleton
    
    private static let shared = Respectlytics()
    
    // MARK: - Private Properties
    
    private var configuration: Configuration?
    private let sessionManager = SessionManager()
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
            
            print("[Respectlytics] ✓ SDK configured (session-based analytics)")
        }
    }
    
    /// Track an event with an optional screen name.
    ///
    /// The SDK automatically collects privacy-safe metadata:
    /// - timestamp, session_id, platform, os_version, app_version, locale
    ///
    /// - Parameters:
    ///   - eventName: Name of the event (e.g., "purchase", "button_clicked")
    ///   - screen: Optional screen name where the event occurred
    public static func track(_ eventName: String, screen: String? = nil) {
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
                screen: screen,
                metadata: EventMetadata.current()
            )
            
            shared.eventQueue.add(event)
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
