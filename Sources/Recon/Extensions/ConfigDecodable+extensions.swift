import Foundation

/// Types that can be produced from a ``ReconConfigValue``, for use with ``ReconFlag``.
public protocol ConfigDecodable {
    /// The config type this Swift type reads as, checked against the key's
    /// declared expectedType when used with ``ReconFlag``.
    static var configType: ReconConfigValueType { get }
    static func from(_ value: ReconConfigValue) -> Self?
}

/// JSON-backed keys can decode straight into a model:
/// `extension FeatureFlags: ConfigDecodable {}` is all that's needed.
extension ConfigDecodable where Self: Decodable {
    public static var configType: ReconConfigValueType { .json }
    public static func from(_ value: ReconConfigValue) -> Self? {
        value.decodedValue()
    }
}

extension String: ConfigDecodable {
    public static var configType: ReconConfigValueType { .string }
    public static func from(_ value: ReconConfigValue) -> String? { value.stringValue }
}

extension Int: ConfigDecodable {
    public static var configType: ReconConfigValueType { .int }
    public static func from(_ value: ReconConfigValue) -> Int? { value.intValue }
}

extension Double: ConfigDecodable {
    public static var configType: ReconConfigValueType { .double }
    public static func from(_ value: ReconConfigValue) -> Double? { value.doubleValue }
}

extension Bool: ConfigDecodable {
    public static var configType: ReconConfigValueType { .bool }
    public static func from(_ value: ReconConfigValue) -> Bool? { value.boolValue }
}

extension Date: ConfigDecodable {
    public static var configType: ReconConfigValueType { .date }
    public static func from(_ value: ReconConfigValue) -> Date? { value.dateValue }
}
