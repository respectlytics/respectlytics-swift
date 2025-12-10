# RespectlyticsSwift

Official Respectlytics SDK for iOS and macOS. Privacy-first analytics with automatic session management, offline support, and zero device identifier collection.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey.svg)](https://developer.apple.com)
[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/respectlytics/respectlytics-swift/releases/tag/2.0.0)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)

## Installation

### Swift Package Manager

Add RespectlyticsSwift to your project using Swift Package Manager:

**In Xcode:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/respectlytics/respectlytics-swift.git`
3. Select version: `2.0.0` or later

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/respectlytics/respectlytics-swift.git", from: "2.0.0")
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
Respectlytics.track("view_product", screen: "ProductDetail")
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

### `track(_:screen:)`

Track an event with an optional screen name.

```swift
// Simple event
Respectlytics.track("button_clicked")

// Event with screen context
Respectlytics.track("add_to_cart", screen: "ProductDetail")
Respectlytics.track("checkout_started", screen: "CartScreen")
```

**Automatic metadata collected:**
- `timestamp` - ISO 8601 format
- `session_id` - Auto-generated, rotates after 2 hours
- `platform` - "iOS" or "macOS"
- `os_version` - e.g., "17.1"
- `app_version` - From your app's bundle
- `locale` - e.g., "en_US"
- `device_type` - "phone", "tablet", or "desktop"

### `flush()`

Force send all queued events immediately. Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.

```swift
Respectlytics.flush()
```

## 🔄 Automatic Session Management

Session IDs are managed entirely by the SDK - no configuration needed.

- **New session on app launch**: Every time your app starts, a fresh session begins
- **2-hour rotation**: Sessions automatically rotate after 2 hours of continuous use
- **RAM-only storage**: Session IDs are never written to disk (designed for GDPR/ePrivacy compliance)
- **No cross-session tracking**: Each session is independent and anonymous

## Automatic Behaviors

The SDK handles these automatically - no developer action needed:

| Feature | Behavior |
|---------|----------|
| **Session Management** | New session ID on app launch, rotates after 2 hours |
| **Event Batching** | Events queued and sent in batches (max 10 events or 30 seconds) |
| **Offline Support** | Events queued when offline, sent when connectivity returns |
| **Retry Logic** | Failed requests retry with exponential backoff (max 3 attempts) |
| **Background Sync** | Events flushed when app enters background |

## Privacy by Design

Your privacy is our priority. Our mobile analytics solution is meticulously designed to provide valuable insights without compromising your data. We achieve this by collecting only session-based data, using anonymized identifiers that are stored only in your device's memory and renewed every two hours or upon app restart. IP addresses are processed transiently for approximate geolocation (country and region) only and are never stored. This privacy-by-design approach ensures that no personal data is retained, making our solution designed to comply with GDPR and the ePrivacy Directive, potentially enabling analytics without user consent in many jurisdictions.

| What we DON'T collect | Why |
|----------------------|-----|
| IDFA / GAID | Device advertising IDs can track users across apps |
| Device fingerprints | Can be used to identify users without consent |
| IP addresses | Processed transiently for country/region lookup, then immediately discarded |
| Custom properties | Prevents accidental PII collection |
| Persistent user IDs | Cross-session tracking requires consent |

| What we DO collect | Purpose |
|-------------------|---------|
| Event name | Analytics |
| Screen name | Navigation analytics |
| Session ID (RAM-only, 2-hour rotation) | Group events within a session |
| Platform, OS version | Debugging |
| App version | Debugging |

### Why No Custom Properties?

Respectlytics uses a strict allowlist to ensure only privacy-safe data can be collected. The API rejects any fields not on this list. This prevents accidental collection of sensitive user data and ensures compliance with privacy regulations.

## Migration from v1.x

### Breaking Changes
- `identify()` method **removed** - no longer needed
- `reset()` method **removed** - no longer needed
- Keychain storage **removed** - sessions are RAM-only

### What to do
1. Remove any calls to `Respectlytics.identify()`
2. Remove any calls to `Respectlytics.reset()`
3. That's it! Session management is now automatic.

### Why This Change?

Storing identifiers on device (Keychain/UserDefaults) requires user consent under ePrivacy Directive Article 5(3). In-memory sessions require no consent, making Respectlytics truly consent-free analytics.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Example App

See the [example](example/) directory for a complete sample implementation.

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
