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
/// The API uses a strict allowlist for privacy protection:
/// - event_name (required)
/// - timestamp, session_id, user_id, screen
/// - platform, os_version, app_version, locale, device_type
///
/// Custom properties are NOT supported - this is by design for privacy.
struct Event: Codable {
    let eventName: String
    let timestamp: String
    let sessionId: String
    let userId: String?
    let screen: String?
    let metadata: EventMetadata
    
    /// Convenience initializer with common parameters
    init(name: String, screen: String?, userId: String?, sessionId: String) {
        self.eventName = name
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.sessionId = sessionId
        self.userId = userId
        self.screen = screen
        self.metadata = EventMetadata.current()
    }
    
    /// Full initializer
    init(eventName: String, timestamp: String, sessionId: String, userId: String?, screen: String?, metadata: EventMetadata) {
        self.eventName = eventName
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.screen = screen
        self.metadata = metadata
    }
    
    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case timestamp
        case sessionId = "session_id"
        case userId = "user_id"
        case screen
        case platform
        case osVersion = "os_version"
        case appVersion = "app_version"
        case locale
        case deviceType = "device_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventName = try container.decode(String.self, forKey: .eventName)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        screen = try container.decodeIfPresent(String.self, forKey: .screen)
        
        // Decode metadata from flattened fields
        let platform = try container.decode(String.self, forKey: .platform)
        let osVersion = try container.decode(String.self, forKey: .osVersion)
        let appVersion = try container.decode(String.self, forKey: .appVersion)
        let locale = try container.decode(String.self, forKey: .locale)
        let deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType) ?? "unknown"
        metadata = EventMetadata(platform: platform, osVersion: osVersion, appVersion: appVersion, locale: locale, deviceType: deviceType)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(screen, forKey: .screen)
        // Flatten metadata into the event
        try container.encode(metadata.platform, forKey: .platform)
        try container.encode(metadata.osVersion, forKey: .osVersion)
        try container.encode(metadata.appVersion, forKey: .appVersion)
        try container.encode(metadata.locale, forKey: .locale)
        try container.encode(metadata.deviceType, forKey: .deviceType)
    }
}

/// Device/app metadata collected automatically
struct EventMetadata: Codable {
    let platform: String
    let osVersion: String
    let appVersion: String
    let locale: String
    let deviceType: String
    
    static func current() -> EventMetadata {
        #if os(iOS)
        let platform = "iOS"
        let osVersion = UIDevice.current.systemVersion
        let deviceType: String = {
            switch UIDevice.current.userInterfaceIdiom {
            case .phone: return "phone"
            case .pad: return "tablet"
            default: return "unknown"
            }
        }()
        #elseif os(macOS)
        let platform = "macOS"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceType = "desktop"
        #else
        let platform = "unknown"
        let osVersion = "unknown"
        let deviceType = "unknown"
        #endif
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let locale = Locale.current.identifier
        
        return EventMetadata(
            platform: platform,
            osVersion: osVersion,
            appVersion: appVersion,
            locale: locale,
            deviceType: deviceType
        )
    }
}
