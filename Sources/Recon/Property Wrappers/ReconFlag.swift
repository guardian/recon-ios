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
public struct ReconFlag<Provider: ReconRemoteConfigProvider, Value: ConfigDecodable> {

    private let providerPath: KeyPath<Recon, Provider>
    private let key: Provider.Key

    /// nonisolated so the wrapper can be declared on any actor: the init only
    /// compares types and stores its inputs — it never touches Recon.shared,
    /// which is read on the main actor when wrappedValue is accessed.
    nonisolated public init(_ providerPath: KeyPath<Recon, Provider>, _ key: Provider.Key) {
        if Value.configType != key.expectedType {
            let message = "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(Value.configType.rawValue)"
            Qalam.Log.console(message, .warning, .named(system: "Recon"))
        }
        self.providerPath = providerPath
        self.key = key
    }

    @MainActor
    public var wrappedValue: Value {
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
