import Foundation

/// A provider-agnostic remote config value.
public struct ReconConfigValue {

    /// The raw string, or `nil` if the key has no fetched value yet.
    public let stringValue: String?

    public init(_ stringValue: String?) {
        self.stringValue = stringValue
    }

    public var intValue: Int? {
        stringValue.flatMap(Int.init)
    }

    public var doubleValue: Double? {
        stringValue.flatMap(Double.init)
    }

    public var boolValue: Bool? {
        switch stringValue?.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }

    /// Parses the raw string as an ISO 8601 date, e.g. "2026-07-12T09:00:00Z",
    /// with or without fractional seconds.
    public var dateValue: Date? {
        guard let stringValue else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: stringValue) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: stringValue)
    }

    /// Parses the raw string as JSON, yielding a dictionary or array.
    public var jsonValue: Any? {
        guard let data = stringValue?.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// Decodes the raw string as JSON into a `Decodable` type.
    public func decodedValue<T: Decodable>(_ type: T.Type = T.self) -> T? {
        guard let data = stringValue?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Whether the raw string parses as the given type.
    public func matches(_ type: ReconConfigValueType) -> Bool {
        switch type {
        case .string: stringValue != nil
        case .int: intValue != nil
        case .double: doubleValue != nil
        case .bool: boolValue != nil
        case .date: dateValue != nil
        case .json: jsonValue != nil
        }
    }
}

extension ReconConfigValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByBooleanLiteral {

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(integerLiteral value: Int) {
        self.init(String(value))
    }

    public init(floatLiteral value: Double) {
        self.init(String(value))
    }

    public init(booleanLiteral value: Bool) {
        self.init(String(value))
    }
}
