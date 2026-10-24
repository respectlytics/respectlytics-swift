//
//  PropertyFilter.swift
//  RespectlyticsSwift
//
//  Copyright (c) 2025 Respectlytics. Licensed under MIT.
//

import Foundation

/// Filters event properties on the device with the server's own shape rules,
/// so a property the server could never keep is not sent at all.
///
/// The server keeps a property only when the app declared it in its Settings on
/// respectlytics.com and the value is one declared there, or a number, kept as
/// the band it falls in. The SDK cannot know what was declared, so it applies
/// the rules every declared property meets:
/// - name: `^[a-z][a-z0-9_]{0,39}$`
/// - text value: `^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,39}$`
/// - number: any finite integer or floating-point value (`Decimal` included)
/// - boolean: as is (for a list declared as "true" / "false")
/// - anything else, `nil` included: dropped
///
/// The name is checked before the value. At most 20 properties are kept, counting
/// only those that passed. A Swift dictionary has no order of its own, so when
/// more than 20 pass, the first 20 by name in alphabetical order are kept.
///
/// Filtering never throws and never stops the event: the event is sent with what
/// passed. What was dropped is reported by name and reason, never by value.
enum PropertyFilter {

    /// Properties one event may carry; the server reads no more than this.
    static let maxProperties = 20

    /// Longest name, and longest text value, the server can keep.
    static let maxLength = 40

    /// Why a property was dropped. Never carries the value. The same reasons,
    /// in the same words, as the other Respectlytics SDKs.
    enum Reason: String, Equatable, Sendable {
        case invalidName = "invalid name"
        case invalidValue = "invalid value"
        case notFinite = "number not finite"
        case unsupportedType = "unsupported type"
        case overLimit = "more than 20"
    }

    /// A property that was not kept.
    struct Dropped: Equatable, Sendable {
        let name: String
        let reason: Reason
    }

    /// What `filter(_:)` kept, and what it dropped in name order.
    struct Filtered: Equatable, Sendable {
        let kept: [String: PropertyValue]
        let dropped: [Dropped]

        static let empty = Filtered(kept: [:], dropped: [])
    }

    /// Keep the properties the server could keep, and name the rest.
    static func filter(_ properties: [String: Any]) -> Filtered {
        var kept: [String: PropertyValue] = [:]
        var dropped: [Dropped] = []

        for (name, raw) in properties.sorted(by: { $0.key < $1.key }) {
            guard isValidName(name) else {
                dropped.append(Dropped(name: name, reason: .invalidName))
                continue
            }
            switch check(raw) {
            case .drop(let reason):
                dropped.append(Dropped(name: name, reason: reason))
            case .keep(let value):
                if kept.count < maxProperties {
                    kept[name] = value
                } else {
                    dropped.append(Dropped(name: name, reason: .overLimit))
                }
            }
        }

        return Filtered(kept: kept, dropped: dropped)
    }

    /// One console line naming what an event dropped and why, without any value.
    /// Names are cut to 40 characters, as the server cuts them in `ignored_properties`.
    static func logLine(eventName: String, dropped: [Dropped]) -> String {
        let items = dropped.map { "\(String($0.name.prefix(maxLength))) (\($0.reason.rawValue))" }
        let count = dropped.count == 1 ? "1 property" : "\(dropped.count) properties"
        return "[Respectlytics] ⚠️ \"\(eventName)\" was sent without \(count): " + items.joined(separator: "; ")
    }

    // MARK: - Shape rules

    /// `^[a-z][a-z0-9_]{0,39}$`
    static func isValidName(_ name: String) -> Bool {
        matches(name, first: isLowercaseLetter) { isLowercaseLetter($0) || isDigit($0) || $0 == UInt8(ascii: "_") }
    }

    /// `^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,39}$`
    static func isValidText(_ text: String) -> Bool {
        matches(text, first: isLetterOrDigit) { byte in
            isLetterOrDigit(byte)
                || byte == UInt8(ascii: " ")
                || byte == UInt8(ascii: "_")
                || byte == UInt8(ascii: ".")
                || byte == UInt8(ascii: "-")
        }
    }

    // MARK: - Private Helpers

    private enum Check {
        case keep(PropertyValue)
        case drop(Reason)
    }

    private static func check(_ raw: Any) -> Check {
        guard let value = unwrapped(raw) else {
            return .drop(.unsupportedType)
        }

        // Objective-C numbers first: an NSNumber holding 1 also casts to Bool,
        // so a real boolean is told apart by its CFBoolean type.
        if type(of: value) is NSNumber.Type, let number = value as? NSNumber {
            return check(number)
        }
        if let text = value as? String {
            return isValidText(text) ? .keep(.string(text)) : .drop(.invalidValue)
        }
        if let text = value as? Substring {
            return isValidText(String(text)) ? .keep(.string(String(text))) : .drop(.invalidValue)
        }
        if let flag = value as? Bool {
            return .keep(.bool(flag))
        }
        if let integer = value as? any BinaryInteger {
            if let exact = Int64(exactly: integer) {
                return .keep(.int(exact))
            }
            return .keep(.double(Double(integer)))
        }
        if let float = value as? any BinaryFloatingPoint {
            return finite(Double(float))
        }
        if let decimal = value as? Decimal {
            return decimal.isNaN ? .drop(.notFinite) : finite(NSDecimalNumber(decimal: decimal).doubleValue)
        }
        return .drop(.unsupportedType)
    }

    private static func check(_ number: NSNumber) -> Check {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return .keep(.bool(number.boolValue))
        }
        if number is NSDecimalNumber {
            return finite(number.doubleValue)
        }
        switch UInt8(bitPattern: number.objCType.pointee) {
        case UInt8(ascii: "f"), UInt8(ascii: "d"):
            return finite(number.doubleValue)
        case UInt8(ascii: "Q"), UInt8(ascii: "L"), UInt8(ascii: "I"), UInt8(ascii: "S"), UInt8(ascii: "C"):
            let unsigned = number.uint64Value
            return unsigned <= UInt64(Int64.max) ? .keep(.int(Int64(unsigned))) : .keep(.double(Double(unsigned)))
        default:
            return .keep(.int(number.int64Value))
        }
    }

    private static func finite(_ number: Double) -> Check {
        number.isFinite ? .keep(.double(number)) : .drop(.notFinite)
    }

    /// The value inside any number of `Optional` layers, or nil for `nil`.
    private static func unwrapped(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return value
        }
        guard let wrapped = mirror.children.first?.value else {
            return nil
        }
        return unwrapped(wrapped)
    }

    private static func matches(_ text: String, first: (UInt8) -> Bool, rest: (UInt8) -> Bool) -> Bool {
        let bytes = text.utf8
        guard (1...maxLength).contains(bytes.count), let head = bytes.first, first(head) else {
            return false
        }
        return bytes.dropFirst().allSatisfy(rest)
    }

    private static func isLowercaseLetter(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    private static func isLetterOrDigit(_ byte: UInt8) -> Bool {
        isLowercaseLetter(byte) || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) || isDigit(byte)
    }
}
