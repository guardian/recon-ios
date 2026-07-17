/// A key into a remote config store: its raw backend name, a default value,
/// and the type its values are expected to parse as.
public protocol ReconConfigKey: Sendable {
    var rawKey: String { get }
    var defaultValue: ReconConfigValue { get }
    var expectedType: ReconConfigValueType { get }
}

extension ReconConfigKey where Self: RawRepresentable, RawValue == String {
    public var rawKey: String { rawValue }
}
