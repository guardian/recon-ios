import Foundation
import Qalam

/// Reads a remote config value as a typed property:
///
///     // Main-actor call sites (SwiftUI views, @MainActor types) — key-path form:
///     @ReconFlag(\.someCoolProvider, .amazingText)
///     private var amazingText: Int
///
///     // Any isolation, including inside an actor — provider-type form:
///     @ReconFlag(SomeCoolProvider.self, .amazingText)
///     private var amazingText: Int
///
/// Returns the provider's currently served value, falling back to the key's
/// default when the served value doesn't parse as Value.
///
/// The two forms differ only in how they locate the provider: the key-path form
/// is @MainActor because forming a key path to Recon's main-actor-isolated
/// provider accessors is only legal from the main actor; the type form is
/// nonisolated, so the wrapper can be declared on any actor. Either way the
/// value itself is read on the main actor when wrappedValue is accessed.
@propertyWrapper
public struct ReconFlag<Provider: ReconRemoteConfigProvider, Value: ConfigDecodable> {

    /// Set by the key-path form; nil when the provider is resolved by type.
    private let providerPath: KeyPath<Recon, Provider>?
    private let key: Provider.Key

    /// Key-path form. @MainActor because a key path to a main-actor-isolated
    /// property can only be formed from the main actor.
    @MainActor
    public init(_ providerPath: KeyPath<Recon, Provider>, _ key: Provider.Key) {
        Self.warnIfTypeMismatch(key)
        self.providerPath = providerPath
        self.key = key
    }

    /// Provider-type form. nonisolated so the wrapper can be declared on any
    /// actor; the provider is looked up by type when the value is read.
    nonisolated public init(_ providerType: Provider.Type = Provider.self, _ key: Provider.Key) {
        Self.warnIfTypeMismatch(key)
        self.providerPath = nil
        self.key = key
    }

    @MainActor
    public var wrappedValue: Value {
        let served = Recon.shared.provider(Provider.self)?.value(for: key) ?? key.defaultValue

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

    private static func warnIfTypeMismatch(_ key: Provider.Key) {
        if Value.configType != key.expectedType {
            let message = "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(Value.configType.rawValue)"
            Qalam.Log.console(message, .warning, .named(system: "Recon"))
        }
    }
}
