import Foundation
import Qalam

/// Reads a remote config value as a typed property:
///
///     @ReconFlag(\.someCoolProvider, .amazingText)
///     private var amazingText: Int
///
/// Returns the provider's currently served value, falling back to the key's
/// default when the served value doesn't parse as `Value`.
@propertyWrapper
public struct ReconFlag<Provider: ReconRemoteConfigProvider, Value> {

    private let read: @MainActor () -> Value

    @MainActor
    public init(_ providerPath: KeyPath<Recon, Provider>, _ key: Provider.Key) where Value: ConfigDecodable {
        if Value.configType != key.expectedType {
            let message = "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(Value.configType.rawValue)"
            Qalam.Log.warning(message, .named("Recon"))
        }
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

    @MainActor
    public var wrappedValue: Value {
        read()
    }
}
