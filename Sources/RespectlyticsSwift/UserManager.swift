//
//  UserManager.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation
import Security

/// Manages user ID generation, persistence, and reset
final class UserManager {
    
    private let keychainKey = "com.respectlytics.userId"
    private let lock = NSLock()
    
    /// Current user ID (nil if not identified)
    private(set) var userId: String?
    
    init() {
        // Try to load existing user ID from Keychain
        userId = readFromKeychain()
    }
    
    /// Generate or retrieve user ID
    func identify() {
        lock.lock()
        defer { lock.unlock() }
        
        // Check Keychain first
        if let stored = readFromKeychain() {
            userId = stored
            return
        }
        
        // Generate new ID (32 lowercase hex chars)
        let newId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        writeToKeychain(newId)
        userId = newId
    }
    
    /// Clear user ID
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        deleteFromKeychain()
        userId = nil
    }
    
    // MARK: - Keychain Helpers
    
    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func writeToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        deleteFromKeychain()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
