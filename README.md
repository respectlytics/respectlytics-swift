# RespectlyticsSwift

Official Respectlytics SDK for iOS and macOS. Privacy-first analytics with automatic session management, offline support, and zero device identifier collection.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)

## Installation

### Swift Package Manager

Add RespectlyticsSwift to your project using Swift Package Manager:

**In Xcode:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/respectlytics/respectlytics-swift.git`
3. Select version: `1.0.1` or later

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/respectlytics/respectlytics-swift.git", from: "1.0.1")
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

// 2. Enable cross-session user tracking (optional)
Respectlytics.identify()

// 3. Track events
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
- `session_id` - Auto-generated, rotates after 30 min inactivity
- `platform` - "iOS" or "macOS"
- `os_version` - e.g., "17.1"
- `app_version` - From your app's bundle
- `locale` - e.g., "en_US"
- `device_type` - "phone", "tablet", or "desktop"

**Privacy by Design:**
The SDK only sends fields from the API's strict allowlist. Custom properties are not supported - this is intentional to protect user privacy.

### `identify()`

Enable cross-session user tracking. Generates and persists a random user ID that will be included in all subsequent events.

```swift
Respectlytics.identify()
```

**Privacy notes:**
- User IDs are auto-generated random UUIDs
- Cannot be overridden with custom IDs (privacy by design)
- Stored in Keychain (persists across app updates, cleared on uninstall)

### `reset()`

Clear the user ID. Call when the user logs out.

```swift
Respectlytics.reset()
```

After reset, subsequent events will be anonymous until `identify()` is called again.

### `flush()`

Force send all queued events immediately. Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.

```swift
Respectlytics.flush()
```

## Automatic Behaviors

The SDK handles these automatically - no developer action needed:

| Feature | Behavior |
|---------|----------|
| **Session Management** | New session ID generated on first event, rotates after 30 min inactivity |
| **Event Batching** | Events queued and sent in batches (max 10 events or 30 seconds) |
| **Offline Support** | Events queued when offline, sent when connectivity returns |
| **Retry Logic** | Failed requests retry with exponential backoff (max 3 attempts) |
| **Background Sync** | Events flushed when app enters background |

## Privacy

RespectlyticsSwift is designed with privacy as a core principle:

### What We Collect
- ✅ Event name and screen (you explicitly track these)
- ✅ Timestamp, session ID, and optional user ID
- ✅ Platform (iOS/macOS), OS version, app version, locale, device type

### What We DO NOT Collect
- ❌ Device identifiers (IDFA, IDFV, etc.)
- ❌ Device model or hardware information
- ❌ Carrier or network details
- ❌ Screen resolution or device name
- ❌ Location data
- ❌ IP addresses (anonymized on server)
- ❌ Custom properties or arbitrary data

### Why No Custom Properties?

Respectlytics uses a strict allowlist to ensure only privacy-safe data can be collected. The API rejects any fields not on this list. This prevents accidental collection of sensitive user data and ensures compliance with privacy regulations.

### User ID Privacy
- User IDs are random UUIDs, not derived from device identifiers
- Cannot be overridden by developers (prevents linking to auth systems)
- Uninstalling the app clears the user ID completely

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

### User ID not persisting

- Check that Keychain access is working on your device
- On simulator, Keychain behavior may differ from physical devices

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

- Documentation: [https://respectlytics.com/docs/](https://respectlytics.com/docs/)
- Issues: [https://github.com/respectlytics/respectlytics-swift/issues](https://github.com/respectlytics/respectlytics-swift/issues)
- Email: respectlytics@loheden.com

---

Made with ❤️ by [Respectlytics](https://respectlytics.com)
