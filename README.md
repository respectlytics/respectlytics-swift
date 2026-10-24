# RespectlyticsSwift

Official Respectlytics SDK for iOS and macOS. Privacy-first analytics with automatic session management and zero device storage or identifier collection.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey.svg)](https://developer.apple.com)
[![Version](https://img.shields.io/badge/version-3.1.2-blue.svg)](https://github.com/respectlytics/respectlytics-swift/releases/tag/v3.1.2)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Installation

### Swift Package Manager

Add RespectlyticsSwift to your project using Swift Package Manager:

**In Xcode:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/respectlytics/respectlytics-swift.git`
3. Select version: `3.1.2` or later

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/respectlytics/respectlytics-swift.git", from: "3.1.2")
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

// For self-hosted instances:
Respectlytics.configure(
    apiKey: "your-api-key",
    apiEndpoint: URL(string: "https://your-server.com/api/v1/events/")!
)
```

That's it! The SDK handles batching, session management, and automatic retries — all in memory, with zero bytes written to device storage.

## API Reference

### `configure(apiKey:apiEndpoint:)`

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

// For self-hosted instances
Respectlytics.configure(
    apiKey: "your-api-key",
    apiEndpoint: URL(string: "https://your-server.com/api/v1/events/")!
)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `apiKey` | `String` | Yes | Your Respectlytics API key |
| `apiEndpoint` | `URL?` | No | Custom endpoint for self-hosted instances |

### `track(_:)`

Track an event.

```swift
Respectlytics.track("button_clicked")
Respectlytics.track("add_to_cart")
Respectlytics.track("checkout_started")
```

**Automatic metadata collected:**
- `timestamp` - ISO 8601 format
- `session_id` - RAM-only, rotates after 2 hours
- `platform` - "iOS" or "macOS"

### `track(_:properties:)`

Track an event with properties. See [Properties and A/B tests](#properties-and-ab-tests).

```swift
Respectlytics.track("paywall_viewed", properties: ["paywall": "b"])
Respectlytics.track("checkout_started", properties: ["price": 7.5])
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventName` | `String` | Yes | Name of the event |
| `properties` | `[String: Any]` | Yes | Names and values: a `String`, a number (`Int`, `Double`, `Decimal` and the like) or a `Bool` |

### `flush()`

Force send all queued events immediately. Rarely needed - the SDK auto-flushes every 30 seconds or when the queue reaches 10 events.

```swift
Respectlytics.flush()
```

## Properties and A/B tests

Send properties with an event to compare groups of users, such as the variants of an A/B test.

```swift
// The variant of an A/B test
Respectlytics.track("paywall_viewed", properties: ["paywall": "b"])

// A number
Respectlytics.track("checkout_started", properties: ["price": 7.5])
```

Properties are kept on paid plans, once you declare them in your app's Settings on respectlytics.com.
Each one is a list of values (such as `a` and `b`), or a number, which is kept only as the band it falls in (such as "5 to 10").
A `Bool` is kept for a list declared as `true` and `false`.
On the free plan, the server drops every property and keeps the event.

What is dropped:

- **Anything you have not declared.** The server drops it and keeps the event.
- **Text that is not one of your values.** The server compares it exactly, so a short value like "John Smith" is dropped there when it is not on your list.
- **Text that cannot be a list value.** The SDK drops it, so it never leaves the device: an email address, a URL, anything over 40 characters. A list value is letters, digits, spaces, `_`, `.` and `-`, and starts with a letter or digit.
- **More than 20 properties.** The SDK sends the first 20 that pass, by name in alphabetical order.

The SDK also drops a name that is not lowercase letters, digits and `_` (starting with a letter, at most 40 characters), a number that is NaN or infinite, and any value that is not text, a number or a `Bool`.
A dropped property never stops the event: the event is sent with what passed.
In debug builds, the console names each dropped property and the reason, never its value.

A self-hosted Community Edition server keeps no properties, and the event is still kept.
If the server is older than this SDK and refuses the properties, the SDK sends the event again without them.

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
| **Offline Support** | Events held in memory when offline, sent when connectivity returns. Unsent events are lost on force-quit (deliberate privacy-first trade-off). |
| **Retry Logic** | Failed requests retry with exponential backoff (max 3 attempts) |
| **Background Sync** | Events flushed when app enters background |

An event the server refuses as invalid (400) is dropped, so it never holds up the events after it.
Once the server has confirmed an event, the SDK does not send it again.
If the server refuses the app key (401), the SDK drops the events it holds and sends nothing more until the app starts again, since no retry can fix a wrong key.

## 🛡️ Privacy by Design

Respectlytics helps developers **avoid collecting personal data** in the first place. Our motto is **Return of Avoidance (ROA)** — the best way to protect sensitive data is to never collect it.

### What We Store (5 fields)

| Field | Purpose |
|-------|---------|
| `event_name` | The action being tracked |
| `timestamp` | When it happened |
| `session_id` | Groups events in a session (RAM-only, 2-hour rotation, hashed server-side) |
| `platform` | iOS, macOS |
| `country` | Derived server-side from IP (IP immediately discarded, never stored) |

On paid plans, an event also keeps the [properties](#properties-and-ab-tests) you declared in your app's Settings: a value from your list, or the band a number falls in.

### What We DON'T Collect

| Data | Why Not |
|------|---------|
| IDFA / IDFV | Device identifiers enable cross-app tracking |
| IP addresses | Processed transiently for country lookup, never stored |
| Device fingerprints | Can be used to identify individuals |
| Undeclared properties | The server drops any property you have not declared, and any value not on your list |
| Persistent user IDs | No cross-session tracking by design |

### Privacy Architecture

- **RAM-only sessions**: Session IDs exist only in device memory, never written to disk
- **RAM-only event queue**: Queued events exist only in device memory — nothing is written to UserDefaults, files, or any device storage for analytics purposes
- **2-hour rotation**: Sessions automatically expire and regenerate
- **New session on restart**: Each app launch starts a fresh session
- **Server-side hashing**: Session IDs are hashed with daily-rotating salt before storage
- **Strict allowlist**: API rejects any field not on its allowlist, and keeps only the properties you declared
- **Open source SDKs**: Full transparency into what data is collected

This architecture is designed to be **transparent** (you know exactly what's collected), **defensible** (minimal data surface), and **clear** (explicit reasoning for each field).

Consult your legal team to determine your specific compliance requirements.

## Migration Guide

### From v3.0.0 to v3.1.0

No code changes needed. `track(_:)` works as before, and an event without properties sends the same body as before.
`track(_:properties:)` is new.

### From v2.x to v3.0.0

**Breaking Change:** The event queue no longer persists to UserDefaults.

In v2.x, queued-but-unsent events were written to `UserDefaults` and survived app force-quit. In v3.0.0, the event queue is fully RAM-only — if the app is force-quit before events are flushed, unsent events are lost.

**Why?** This is a deliberate privacy-first design choice. Zero bytes are written to device storage for analytics purposes. The SDK auto-flushes every 30 seconds, on 10 queued events, and when the app enters background, so the event loss window is narrow.

**What to do:** No code changes needed. The public API (`configure`, `track`, `flush`) is unchanged. If your app relied on events surviving force-quit, be aware that this is no longer the case.

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

### A property does not appear

1. In a debug build, check the console: the SDK names each property it dropped and why
2. Check that the property is declared in your app's Settings on respectlytics.com
3. Check that your plan includes properties

### "SDK not configured" warning

Make sure to call `Respectlytics.configure(apiKey:)` before any other SDK methods.

## License

This SDK is licensed under the [MIT License](LICENSE).

## Support

- Documentation: [https://respectlytics.com/sdk/](https://respectlytics.com/sdk/)
- Issues: [https://github.com/respectlytics/respectlytics-swift/issues](https://github.com/respectlytics/respectlytics-swift/issues)
- Email: respectlytics@loheden.com

---

Made with ❤️ by [Respectlytics](https://respectlytics.com)
