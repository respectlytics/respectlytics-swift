// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RespectlyticsSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "RespectlyticsSwift",
            targets: ["RespectlyticsSwift"]
        ),
    ],
    targets: [
        .target(
            name: "RespectlyticsSwift",
            dependencies: [],
            path: "Sources/RespectlyticsSwift"
        ),
        .testTarget(
            name: "RespectlyticsSwiftTests",
            dependencies: ["RespectlyticsSwift"],
            path: "Tests/RespectlyticsSwiftTests"
        ),
    ]
)
