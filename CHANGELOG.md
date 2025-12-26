# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-12-26

### ⚠️ Breaking Changes
- **REMOVED**: `screen` parameter from `track()` method
- **REMOVED**: `os_version`, `app_version`, `locale`, `device_type` from event payload

### Changed
- Event payload now contains only 4 fields: `event_name`, `timestamp`, `session_id`, `platform`
- Simplified Event model (removed EventMetadata struct)
- Updated privacy documentation to emphasize Return of Avoidance (ROA) approach

### Why This Change?
The API now uses a strict 4-field allowlist. Additional fields are silently ignored for backwards
compatibility but never stored. This minimizes data collection and strengthens privacy guarantees.

### Migration
Remove the `screen` parameter from any `track()` calls:

```swift
// Before (v2.0.x)
Respectlytics.track("view_product", screen: "ProductDetail")

// After (v2.1.0)
Respectlytics.track("view_product")
```

If you need screen context, include it in the event name: `product_detail_view_product`

---

## [2.0.0] - 2025-12-10

### ⚠️ Breaking Changes
- **REMOVED**: `identify()` method
- **REMOVED**: `reset()` method
- **REMOVED**: Keychain storage for user IDs
- **REMOVED**: `UserManager` class entirely

### Changed
- Session IDs now generated in RAM only (never persisted to disk)
- New session ID generated on every app launch
- Session timeout changed from 30 minutes to 2 hours
- Sessions rotate automatically every 2 hours of continuous use
- Event payloads no longer include `user_id` field

### Migration
Remove any calls to `identify()` and `reset()`. Session management is now automatic.

```swift
// Before (v1.x)
Respectlytics.configure(apiKey: "your-api-key")
Respectlytics.identify()  // ❌ Remove this
Respectlytics.track("event")
Respectlytics.reset()     // ❌ Remove this

// After (v2.0.0)
Respectlytics.configure(apiKey: "your-api-key")
Respectlytics.track("event")  // ✅ That's it!
```

---

## [1.0.2] - 2025-11-30

### Changed
- Standardized privacy documentation across all Respectlytics SDKs
- Clarified IP address handling: "Used only for geolocation lookup, then discarded"
- Updated README with consistent "Privacy by Design" section format

## [1.0.1] - 2025-11-30

### Fixed
- Minor documentation updates

## [1.0.0] - 2025-11-30

### Added
- Initial release of RespectlyticsSwift SDK
- `configure(apiKey:)` - Initialize SDK with your API key
- `track(_:screen:)` - Track events with optional screen name
- `identify()` - Enable cross-session user tracking with auto-generated user ID
- `reset()` - Clear user ID for logout scenarios
- `flush()` - Force send queued events (rarely needed)
- Automatic session management with 30-minute timeout rotation
- Offline event queue with automatic retry when connectivity returns
- Background flush when app enters background (iOS)
- Event persistence to UserDefaults (survives force-quit/crash)
- Keychain storage for user ID
- Automatic metadata collection: platform, os_version, app_version, locale, device_type
- 3-retry exponential backoff for network failures

### Privacy Features
- User IDs are randomly generated UUIDs, never linked to device identifiers
- No IDFA, IDFV, or any device identifiers collected
- User ID cleared on app uninstall
- No custom properties - only screen name allowed (by design)

### Platforms
- iOS 15.0+
- macOS 12.0+
- Swift 5.9+
- Xcode 15.0+
