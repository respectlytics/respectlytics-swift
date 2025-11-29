//
//  SessionManager.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation

/// Manages session ID generation and rotation
final class SessionManager {
    
    private var sessionId: String?
    private var lastEventTime: Date?
    private let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
    
    private let lock = NSLock()
    
    /// Get current session ID, rotating if necessary
    func getSessionId() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        
        // Check if session expired
        if let lastTime = lastEventTime,
           now.timeIntervalSince(lastTime) > sessionTimeout {
            sessionId = nil // Force new session
        }
        
        // Generate new session if needed
        if sessionId == nil {
            sessionId = generateSessionId()
        }
        
        lastEventTime = now
        return sessionId!
    }
    
    /// Generate a new session ID (32 lowercase hex characters)
    private func generateSessionId() -> String {
        return UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }
}
