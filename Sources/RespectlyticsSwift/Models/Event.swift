//
//  Event.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Represents an analytics event.
///
/// This struct only contains fields that are accepted by the Respectlytics API.
/// The API stores 5 fields for every event — these 4 sent by the SDK plus `country`
/// (derived server-side from IP, which is immediately discarded):
/// - event_name (required)
/// - timestamp
/// - session_id
/// - platform
///
/// An event may also carry `properties`, already filtered on the device by
/// `PropertyFilter`. The server keeps only the ones the app declared in its
/// Settings. Without properties the key is left out of the JSON entirely, so
/// the body is exactly what SDKs before 3.1.0 sent.
/// Note: user_id is NOT supported. Respectlytics uses session-based analytics only.
struct Event: Codable {
    let eventName: String
    let timestamp: String
    let sessionId: String
    let platform: String
    /// nil when the event carries no properties (never an empty object).
    let properties: [String: PropertyValue]?

    /// Create an event
    init(eventName: String, sessionId: String, properties: [String: PropertyValue] = [:]) {
        self.eventName = eventName
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.sessionId = sessionId
        self.platform = Event.currentPlatform()
        self.properties = properties.isEmpty ? nil : properties
    }

    /// Full initializer (for decoding)
    init(eventName: String, timestamp: String, sessionId: String, platform: String, properties: [String: PropertyValue]? = nil) {
        self.eventName = eventName
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.platform = platform
        self.properties = properties?.isEmpty == true ? nil : properties
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
        case properties
    }
}
