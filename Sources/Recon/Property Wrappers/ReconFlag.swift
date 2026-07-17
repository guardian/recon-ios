import Foundation

/// Selects a group of keys rather than a single one, for use with ``ReconFlag``.
public enum KeySelection: Sendable {
    case all
}

/// Reads a remote config value as a typed property:
///
///     @ReconFlag(\.someCoolProvider, .amazingText)
///     private var amazingText: Int
///
/// Returns the provider's currently served value, falling back to the key's
/// default when the served value doesn't parse as `Value`.
///
/// Can also list every key a provider knows about:
///
///     @ReconFlag(\.someCoolProvider, .all)
///     private var allFlags: [SomeCoolProviderKey]
@propertyWrapper
public struct MyRCFlag<Provider: ReconRemoteConfigProvider, Value> {

    private let read: @MainActor () -> Value

    public init(_ providerPath: KeyPath<Recon, Provider> & Sendable, _ key: Provider.Key) where Value: ConfigDecodable {
        self.read = {
            let served = Recon.shared[keyPath: providerPath].value(for: key)
            if let value = Value.from(served) {
                return value
            }
            guard let fallback = Value.from(key.defaultValue) else {
                preconditionFailure(
                    "default for '\(key.rawKey)' does not parse as \(Value.self); the property type likely doesn't match the key's expectedType"
                )
            }
            return fallback
        }
    }

    public init(_ providerPath: KeyPath<Recon, Provider> & Sendable, _ selection: KeySelection) where Value == [Provider.Key] {
        self.read = {
            switch selection {
            case .all: Array(Provider.Key.allCases)
            }
        }
    }

    @MainActor
    public var wrappedValue: Value {
        read()
    }
}
