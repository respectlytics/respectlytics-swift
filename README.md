# RespectlyticsSwift

Official Respectlytics SDK for iOS and macOS. Privacy-first analytics with automatic session management, offline support, and zero device identifier collection.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey.svg)](https://developer.apple.com)
[![Version](https://img.shields.io/badge/version-2.1.0-blue.svg)](https://github.com/respectlytics/respectlytics-swift/releases/tag/2.1.0)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)

## Installation

### Swift Package Manager

Add RespectlyticsSwift to your project using Swift Package Manager:

**In Xcode:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/respectlytics/respectlytics-swift.git`
3. Select version: `2.1.0` or later

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/respectlytics/respectlytics-swift.git", from: "2.1.0")
]
```

Then add the dependency to your target:
```swift
.target(
    name: "YourApp",
    dependencies: ["RespectlyticsSwift"]
)
```

## Quick Start

```swift
import RespectlyticsSwift

// 1. Configure at app launch (AppDelegate or @main App init)
Respectlytics.configure(apiKey: "your-api-key")

// 2. Track events
Respectlytics.track("purchase")
```

That's it! The SDK handles batching, offline queue, session management, and automatic retries.

## API Reference

### `configure(apiKey:)`

Initialize the SDK with your API key. Call once at app launch.

```swift
// In AppDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Respectlytics.configure(apiKey: "your-api-key")
    return true
}

// Or in SwiftUI @main App
@main
struct MyApp: App {
    init() {
        Respectlytics.configure(apiKey: "your-api-key")
    }
    // ...
}
```

### `track(_:)`

Track an event. Custom properties are not supported (privacy by design).

```swift
Respectlytics.track("button_clicked")
Respectlytics.track("add_to_cart")
Respectlytics.track("checkout_started")
```

**Automatic metadata collected:**
- `timestamp` - ISO 8601 format
- `session_id` - RAM-only, rotates after 2 hours
- `platform` - "iOS" or "macOS"

### `flush()`

Force send all queued events immediately. Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.

```swift
Respectlytics.flush()
```

## 🔄 Automatic Session Management

Session IDs are managed entirely by the SDK - no configuration needed.

- **New session on app launch**: Every time your app starts, a fresh session begins
- **2-hour rotation**: Sessions automatically rotate after 2 hours of continuous use
- **RAM-only storage**: Session IDs are never written to disk
- **No cross-session tracking**: Each session is independent

## Automatic Behaviors

The SDK handles these automatically - no developer action needed:

| Feature | Behavior |
|---------|----------|
| **Session Management** | New session ID on app launch, rotates after 2 hours |
| **Event Batching** | Events queued and sent in batches (max 10 events or 30 seconds) |
| **Offline Support** | Events queued when offline, sent when connectivity returns |
| **Retry Logic** | Failed requests retry with exponential backoff (max 3 attempts) |
| **Background Sync** | Events flushed when app enters background |

## 🛡️ Privacy by Design

Respectlytics helps developers **avoid collecting personal data** in the first place. Our motto is **Return of Avoidance (ROA)** — the best way to protect sensitive data is to never collect it.

### What We Store (4 fields only)

| Field | Purpose |
|-------|---------|
| `event_name` | The action being tracked |
| `timestamp` | When it happened |
| `session_id` | Groups events in a session (RAM-only, 2-hour rotation, hashed server-side) |
| `platform` | iOS, macOS |

Country is derived server-side from IP address, then the IP is immediately discarded.

### What We DON'T Collect

| Data | Why Not |
|------|---------|
| IDFA / IDFV | Device identifiers enable cross-app tracking |
| IP addresses | Processed transiently for country lookup, never stored |
| Device fingerprints | Can be used to identify individuals |
| Custom properties | API rejects extra fields to prevent accidental PII |
| Persistent user IDs | No cross-session tracking by design |

### Privacy Architecture

- **RAM-only sessions**: Session IDs exist only in device memory, never written to disk
- **2-hour rotation**: Sessions automatically expire and regenerate
- **New session on restart**: Each app launch starts a fresh session
- **Server-side hashing**: Session IDs are hashed with daily-rotating salt before storage
- **Strict allowlist**: API rejects any fields not on the 4-field allowlist
- **Open source SDKs**: Full transparency into what data is collected

This architecture is designed to be **transparent** (you know exactly what's collected), **defensible** (minimal data surface), and **clear** (explicit reasoning for each field).

Consult your legal team to determine your specific compliance requirements.

## Migration Guide

### From v2.0.x to v2.1.0

**Breaking Change:** The `screen` parameter has been removed from `track()`.

```diff
- Respectlytics.track("view_product", screen: "ProductDetail")
+ Respectlytics.track("view_product")
```

If you need screen context, include it in your event name (e.g., `product_detail_view_product`).

### From v1.x to v2.x

**Breaking Changes:**
- `identify()` method **removed** - no longer needed
- `reset()` method **removed** - no longer needed
- Keychain storage **removed** - sessions are RAM-only

**What to do:**
1. Remove any calls to `Respectlytics.identify()`
2. Remove any calls to `Respectlytics.reset()`
3. That's it! Session management is now automatic.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Troubleshooting

### Events not appearing in dashboard

1. Verify your API key is correct
2. Check console for `[Respectlytics]` log messages
3. Call `Respectlytics.flush()` to force send events
4. Ensure you have network connectivity

### "SDK not configured" warning

Make sure to call `Respectlytics.configure(apiKey:)` before any other SDK methods.

## License

This SDK is provided under a proprietary license. See the [LICENSE](LICENSE) file for details.

**Permitted:**
- View source code for transparency and security review
- Install via Swift Package Manager
- Use with official Respectlytics service

**Prohibited:**
- Copying, forking, or redistributing source code
- Modifying the SDK
- Using with non-Respectlytics backends

## Support

- Documentation: [https://respectlytics.com/sdk/](https://respectlytics.com/sdk/)
- Issues: [https://github.com/respectlytics/respectlytics-swift/issues](https://github.com/respectlytics/respectlytics-swift/issues)
- Email: respectlytics@loheden.com

---

Made with ❤️ by [Respectlytics](https://respectlytics.com)
