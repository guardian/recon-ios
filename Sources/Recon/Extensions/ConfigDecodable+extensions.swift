import Foundation

/// Types that can be produced from a ``ReconConfigValue``, for use with ``ReconFlag``.
public protocol ConfigDecodable {
    static func from(_ value: ReconConfigValue) -> Self?
}

/// JSON-backed keys can decode straight into a model:
/// `extension FeatureFlags: ConfigDecodable {}` is all that's needed.
extension ConfigDecodable where Self: Decodable {
    public static func from(_ value: ReconConfigValue) -> Self? {
        value.decodedValue()
    }
}

extension String: ConfigDecodable {
    public static func from(_ value: ReconConfigValue) -> String? { value.stringValue }
}

extension Int: ConfigDecodable {
    public static func from(_ value: ReconConfigValue) -> Int? { value.intValue }
}

extension Double: ConfigDecodable {
    public static func from(_ value: ReconConfigValue) -> Double? { value.doubleValue }
}

extension Bool: ConfigDecodable {
    public static func from(_ value: ReconConfigValue) -> Bool? { value.boolValue }
}

extension Date: ConfigDecodable {
    public static func from(_ value: ReconConfigValue) -> Date? { value.dateValue }
}
