//
//  Configuration.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. All rights reserved.
//

import Foundation

/// SDK configuration
struct Configuration {
    let apiKey: String
    let apiEndpoint: URL
    
    init(apiKey: String, apiEndpoint: URL = URL(string: "https://respectlytics.com/api/v1/events/")!) {
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
    }
}
