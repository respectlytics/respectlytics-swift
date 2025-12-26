//
//  Event.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Represents an analytics event.
///
/// This struct only contains fields that are accepted by the Respectlytics API.
/// The API uses a strict allowlist - only 4 fields are stored:
/// - event_name (required)
/// - timestamp
/// - session_id
/// - platform
///
/// Country is derived server-side from IP, which is immediately discarded.
/// Note: user_id is NOT supported. Respectlytics uses session-based analytics only.
struct Event: Codable {
    let eventName: String
    let timestamp: String
    let sessionId: String
    let platform: String

    /// Create an event
    init(eventName: String, sessionId: String) {
        self.eventName = eventName
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.sessionId = sessionId
        self.platform = Event.currentPlatform()
    }

    /// Full initializer (for decoding)
    init(eventName: String, timestamp: String, sessionId: String, platform: String) {
        self.eventName = eventName
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.platform = platform
    }

    private static func currentPlatform() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #else
        return "unknown"
        #endif
    }

    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case timestamp
        case sessionId = "session_id"
        case platform
    }
}
