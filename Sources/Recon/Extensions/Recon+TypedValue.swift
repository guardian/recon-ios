import Foundation
import Qalam

/// Non-optional typed reads. Unlike boolValue/intValue/… which return an
/// optional you have to ?? default at the call site, these fall back to the
/// key's own declared defaultValue, so there's never a fallback to write:
///
///     let isEnabled: Bool = Recon.shared.value(\.firebase, .isCheckoutV2Enabled)
///     let isEnabled: Bool = Recon.value(\.firebase, .isCheckoutV2Enabled)   // static alias
///
/// The served value is parsed as Value; if the provider isn't registered or
/// the served value doesn't parse, the key's default is returned instead.
extension Recon {

    /// Key-path form. The key path only exists to infer P at the call site.
    public func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerPath: KeyPath<Recon, P>,
        _ key: P.Key
    ) -> Value {
        typedValue(P.self, key)
    }

    /// Provider-type form, usable without a key path (e.g. off the main actor's
    /// key-path accessors).
    public func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerType: P.Type = P.self,
        _ key: P.Key
    ) -> Value {
        typedValue(P.self, key)
    }

    private func typedValue<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerType: P.Type,
        _ key: P.Key
    ) -> Value {
        if Value.configType != key.expectedType {
            Qalam.Log.console(
                "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(Value.configType.rawValue)",
                .warning,
                .named(system: "Recon")
            )
        }
        let served = provider(P.self)?.value(for: key) ?? key.defaultValue
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

/// Static alias so call sites can read Recon.value(...) without .shared.
extension Recon {

    @MainActor
    public static func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerPath: KeyPath<Recon, P>,
        _ key: P.Key
    ) -> Value {
        shared.value(providerPath, key)
    }

    @MainActor
    public static func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerType: P.Type = P.self,
        _ key: P.Key
    ) -> Value {
        shared.value(providerType, key)
    }
}
