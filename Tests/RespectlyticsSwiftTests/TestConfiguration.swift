//
//  TestConfiguration.swift
//  RespectlyticsSwift
//
//  Environment-based test configuration for integration tests
//

import Foundation

/// Configuration for integration tests, read from environment variables
struct TestConfiguration {
    
    // MARK: - Environment Keys
    
    private static let apiKeyEnvVar = "RESPECTLYTICS_TEST_API_KEY"
    private static let testBaseURLEnvVar = "RESPECTLYTICS_TEST_BASE_URL"
    private static let prodBaseURLEnvVar = "RESPECTLYTICS_PROD_BASE_URL"
    
    // MARK: - Default Values
    
    private static let defaultTestURL = "http://localhost:8000/api/v1"
    private static let defaultProdURL = "https://respectlytics.com/api/v1"
    
    // MARK: - Properties
    
    /// API key from environment, or nil if not set
    static var apiKey: String? {
        let value = ProcessInfo.processInfo.environment[apiKeyEnvVar]
        if value == "your-api-key-here" || value?.isEmpty == true {
            return nil
        }
        return value
    }
    
    /// Test server base URL
    static var testBaseURL: String {
        ProcessInfo.processInfo.environment[testBaseURLEnvVar] ?? defaultTestURL
    }
    
    /// Production server base URL
    static var prodBaseURL: String {
        ProcessInfo.processInfo.environment[prodBaseURLEnvVar] ?? defaultProdURL
    }
    
    /// Full events endpoint for test server
    static var testEventsURL: String {
        "\(testBaseURL)/events/"
    }
    
    /// Full events endpoint for production server
    static var prodEventsURL: String {
        "\(prodBaseURL)/events/"
    }
    
    /// Returns the base URL to use for tests
    static var activeBaseURL: String {
        testBaseURL
    }
    
    /// Returns the events URL to use for tests
    static var activeEventsURL: String {
        testEventsURL
    }
    
    // MARK: - Diagnostic Output
    
    /// Print test environment status
    static func printEnvironmentStatus() {
        print("")
        print("🔍 Test Configuration:")
        
        if let key = apiKey {
            let masked = String(key.prefix(8)) + "..." + String(key.suffix(4))
            print("   ├─ API Key: ✅ \(masked)")
        } else {
            print("   ├─ API Key: ❌ Not set")
        }
        
        print("   └─ Target: \(activeEventsURL)")
        print("")
    }
}
