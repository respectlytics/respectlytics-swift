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

/// Represents an analytics event
struct Event: Codable {
    let eventName: String
    let timestamp: String
    let sessionId: String
    let userId: String?
    let properties: [String: AnyCodable]?
    let metadata: EventMetadata
    
    /// Convenience initializer with common parameters
    init(name: String, properties: [String: Any]?, userId: String?, sessionId: String) {
        self.eventName = name
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.sessionId = sessionId
        self.userId = userId
        self.properties = properties?.mapValues { AnyCodable($0) }
        self.metadata = EventMetadata.current()
    }
    
    /// Full initializer
    init(eventName: String, timestamp: String, sessionId: String, userId: String?, properties: [String: Any]?, metadata: EventMetadata) {
        self.eventName = eventName
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.userId = userId
        self.properties = properties?.mapValues { AnyCodable($0) }
        self.metadata = metadata
    }
    
    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case timestamp
        case sessionId = "session_id"
        case userId = "user_id"
        case properties
        case platform
        case osVersion = "os_version"
        case appVersion = "app_version"
        case locale
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventName = try container.decode(String.self, forKey: .eventName)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        properties = try container.decodeIfPresent([String: AnyCodable].self, forKey: .properties)
        
        // Decode metadata from flattened fields
        let platform = try container.decode(String.self, forKey: .platform)
        let osVersion = try container.decode(String.self, forKey: .osVersion)
        let appVersion = try container.decode(String.self, forKey: .appVersion)
        let locale = try container.decode(String.self, forKey: .locale)
        metadata = EventMetadata(platform: platform, osVersion: osVersion, appVersion: appVersion, locale: locale)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(properties, forKey: .properties)
        // Flatten metadata into the event
        try container.encode(metadata.platform, forKey: .platform)
        try container.encode(metadata.osVersion, forKey: .osVersion)
        try container.encode(metadata.appVersion, forKey: .appVersion)
        try container.encode(metadata.locale, forKey: .locale)
    }
}

/// Device/app metadata collected automatically
struct EventMetadata: Codable {
    let platform: String
    let osVersion: String
    let appVersion: String
    let locale: String
    
    static func current() -> EventMetadata {
        #if os(iOS)
        let platform = "iOS"
        let osVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
        let platform = "macOS"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #else
        let platform = "unknown"
        let osVersion = "unknown"
        #endif
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let locale = Locale.current.identifier
        
        return EventMetadata(
            platform: platform,
            osVersion: osVersion,
            appVersion: appVersion,
            locale: locale
        )
    }
}

/// Type-erased Codable wrapper for properties
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if value is NSNull {
            try container.encodeNil()
        } else {
            try container.encode(String(describing: value))
        }
    }
}
