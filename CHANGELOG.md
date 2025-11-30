# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
