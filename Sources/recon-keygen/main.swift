//
// Generates a RemoteConfigKey enum from a plist of key/default pairs, so the
// plist is the single source of truth while call sites keep compile-time safety.
//
// Usage: swift run recon-keygen <defaults.plist> <output.swift>

import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 4 else {
    fail("usage: generate-config-keys.swift <defaults.plist> <output.swift>")
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let enumName = CommandLine.arguments[3]

guard let data = FileManager.default.contents(atPath: inputPath) else {
    fail("cannot read \(inputPath)")
}
guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let entries = plist as? [String: Any] else {
    fail("\(inputPath) must contain a dictionary of key/default pairs at its root")
}

/// Xcode picks lines in this format out of the tool's output and shows them
/// as build warnings on the plist.
func warn(_ message: String) {
    print("\(inputPath): warning: \(message)")
}

func expiryDate(from raw: Any, key: String) -> Date {
    if let date = raw as? Date { return date }
    if let string = raw as? String, let date = ISO8601DateFormatter().date(from: string) {
        return date
    }
    fail("key '\(key)' has an invalid 'expires'; use a plist date or an ISO 8601 string")
}

// An entry may wrap its default to attach an expiry date:
//
//     <key>ben_int</key>
//     <dict>
//         <key>value</key><integer>0</integer>
//         <key>expires</key><date>2026-08-01T00:00:00Z</date> <---- This is optional.
//     </dict>
//
// Dictionaries with any other keys remain JSON defaults, as before.
var defaults: [String: Any] = [:]
for (key, raw) in entries {
    guard let annotated = raw as? [String: Any],
          let value = annotated["value"],
          Set(annotated.keys).isSubset(of: ["value", "expires"]) else {
        defaults[key] = raw
        continue
    }
    defaults[key] = value
    if let expires = annotated["expires"] {
        let expiry = expiryDate(from: expires, key: key)
        if expiry < Date() {
            let formatted = ISO8601DateFormatter().string(from: expiry)
            warn("flag '\(key)' expired on \(formatted); remove it or extend its expiry")
        }
    }
}

/// "dana_string" -> "danaString"
func caseName(for key: String) -> String {
    let parts = key.split(separator: "_")
    guard let first = parts.first else { fail("empty key in \(inputPath)") }
    return parts.dropFirst().reduce(String(first)) { $0 + $1.prefix(1).uppercased() + $1.dropFirst() }
}

func stringLiteral(_ string: String) -> String {
    let escaped = string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

/// Emits the ConfigValue literal matching the plist entry's native type.
/// Dates become ISO 8601 strings; dictionaries and arrays become JSON strings.
func literal(for value: Any, key: String) -> String {
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        if CFNumberIsFloatType(number) {
            return String(number.doubleValue)
        }
        return String(number.intValue)
    }
    if let string = value as? String {
        // Strings holding JSON (for .jsonValue consumers) must actually parse,
        // so a typo fails generation instead of returning nil at runtime.
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            guard let data = trimmed.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                fail("key '\(key)' looks like JSON but does not parse")
            }
        }
        return stringLiteral(string)
    }
    if let date = value as? Date {
        return stringLiteral(ISO8601DateFormatter().string(from: date))
    }
    if value is [String: Any] || value is [Any] {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            fail("key '\(key)' contains a collection that cannot be represented as JSON")
        }
        return stringLiteral(json)
    }
    fail("key '\(key)' has unsupported type \(type(of: value)); use string, integer, real, boolean, date, dictionary, or array")
}

/// Maps the plist entry's native type to the ConfigType the generated key
/// advertises. JSON-in-string is classified here, at generation time, where
/// literal(for:key:) has already guaranteed that it parses.
func configType(for value: Any, key: String) -> String {
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return ".bool" }
        if CFNumberIsFloatType(number) { return ".double" }
        return ".int"
    }
    if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) ? ".json" : ".string"
    }
    if value is Date { return ".date" }
    if value is [String: Any] || value is [Any] { return ".json" }
    fail("key '\(key)' has unsupported type \(type(of: value)); use string, integer, real, boolean, date, dictionary, or array")
}

let sortedKeys = defaults.keys.sorted()

var output = """
// AUTO-GENERATED from \(inputPath.split(separator: "/").last ?? "plist") — do not edit by hand.
//
// The Guardian.

import Recon

enum \(enumName)Key: String, RemoteConfigKey, CaseIterable {

"""

for key in sortedKeys {
    output += "    case \(caseName(for: key)) = \"\(key)\"\n"
}

output += """

    var defaultValue: ConfigValue {
        switch self {

"""

for key in sortedKeys {
    output += "        case .\(caseName(for: key)): \(literal(for: defaults[key]!, key: key))\n"
}

output += """
        }
    }

    var expectedType: ConfigType {
        switch self {

"""

for key in sortedKeys {
    output += "        case .\(caseName(for: key)): \(configType(for: defaults[key]!, key: key))\n"
}

output += """
        }
    }
}

"""

do {
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
} catch {
    fail("cannot write \(outputPath): \(error)")
}
