//
//  SessionManager.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation

/// Manages session ID generation and automatic 2-hour rotation.
///
/// Session IDs are:
/// - Generated fresh on every app launch (RAM-only, never persisted)
/// - Automatically rotated after 2 hours of continuous use
/// - 32 lowercase hexadecimal characters (UUID without dashes)
///
/// This design ensures GDPR/ePrivacy compliance - no device storage means no consent required.
final class SessionManager {
    
    /// Current session ID (generated on init, never persisted)
    private var sessionId: String
    
    /// Timestamp when current session started
    private var sessionStart: Date
    
    /// Session timeout: 2 hours (7200 seconds)
    private let sessionTimeout: TimeInterval = 7200
    
    private let lock = NSLock()
    
    init() {
        // New session on every app launch - RAM only
        self.sessionId = SessionManager.generateSessionId()
        self.sessionStart = Date()
    }
    
    /// Get current session ID, rotating if 2 hours have elapsed.
    func getSessionId() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        
        // Rotate session after 2 hours of continuous use
        if now.timeIntervalSince(sessionStart) > sessionTimeout {
            sessionId = SessionManager.generateSessionId()
            sessionStart = now
        }
        
        return sessionId
    }
    
    /// Generate a new session ID (32 lowercase hex characters)
    private static func generateSessionId() -> String {
        return UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }
}
