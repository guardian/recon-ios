import Foundation
import Qalam

/// Non-optional, crash-safe typed reads.
///
/// These are the **recommended** way to read a flag outside of a stored
/// property (where you'd reach for ``ReconFlag`` instead). Unlike the optional
/// accessors (boolValue, intValue, …) you never write a ?? default at the
/// call site: the value falls back to the key's own declared
/// ``ReconConfigKey/defaultValue``.
///
///swift
/// let isEnabled: Bool = Recon.value(\.firebase, .isCheckoutV2Enabled)
/// let retries: Int = Recon.shared.value(\.firebase, .maxRetryCount)
///

///
/// - Important: The result type drives which value is read, so the call site
///   must annotate it. `let x: Bool = Recon.value(…)` compiles; a bare
///   `let x = Recon.value(…)` does not.
///
/// ### Safety
/// The provider is resolved by type with a fallback, so these **never crash on
/// a missing provider** — if nothing is registered for `P`, or the served value
/// doesn't parse, you get the key's default. The single exception is a
/// programmer error: if the property's type can't represent the key's declared
/// type (e.g. reading a `.string` key as `Bool`), the read traps with a
/// `preconditionFailure` after logging a warning.
extension Recon {

    /// Reads `key` as `Value`, falling back to the key's default.
    ///
    /// ```swift
    /// let isEnabled: Bool = Recon.shared.value(\.firebase, .isCheckoutV2Enabled)
    /// ```
    ///
    /// - Parameters:
    ///   - providerPath: Key path to the provider, e.g. `\.firebase`. Used only
    ///     to infer the provider type `P` at the call site.
    ///   - key: The key to read.
    /// - Returns: The served value parsed as `Value`, or the key's
    ///   ``ReconConfigKey/defaultValue`` when the provider isn't registered or
    ///   the served value doesn't parse.
    /// - Warning: Forming the `\.firebase` key path requires the main actor. In
    ///   a non-main-actor context, use the provider-type overload instead.
    public func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerPath: KeyPath<Recon, P>,
        _ key: P.Key
    ) -> Value {
        typedValue(P.self, key)
    }

    /// Reads `key` as `Value` by provider **type**, falling back to the key's default.
    ///
    /// Prefer this form off the main actor, where the `\.firebase` key path
    /// can't be formed:
    ///
    /// ```swift
    /// let isEnabled: Bool = await Recon.value(FirebaseConfigProvider.self, .isCheckoutV2Enabled)
    /// ```
    ///
    /// - Parameters:
    ///   - providerType: The provider type to read from. Defaults to `P.self`,
    ///     so it can usually be inferred and omitted.
    ///   - key: The key to read.
    /// - Returns: The served value parsed as `Value`, or the key's
    ///   ``ReconConfigKey/defaultValue`` when the provider isn't registered or
    ///   the served value doesn't parse.
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

/// Static aliases so call sites can read `Recon.value(...)` without spelling out
/// `.shared`. These forward to the instance methods above and share their
/// crash-safe behaviour.
extension Recon {

    /// Static alias for ``value(_:_:)-(KeyPath<Recon,_>,_)``.
    ///
    /// ```swift
    /// let isEnabled: Bool = Recon.value(\.firebase, .isCheckoutV2Enabled)
    /// ```
    ///
    /// - Parameters:
    ///   - providerPath: Key path to the provider, used only to infer `P`.
    ///   - key: The key to read.
    /// - Returns: The served value parsed as `Value`, or the key's default.
    @MainActor
    public static func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerPath: KeyPath<Recon, P>,
        _ key: P.Key
    ) -> Value {
        shared.value(providerPath, key)
    }

    /// Static alias for the provider-type ``value(_:_:)-(P.Type,_)``.
    ///
    /// - Parameters:
    ///   - providerType: The provider type to read from. Defaults to `P.self`.
    ///   - key: The key to read.
    /// - Returns: The served value parsed as `Value`, or the key's default.
    @MainActor
    public static func value<P: ReconRemoteConfigProvider, Value: ConfigDecodable>(
        _ providerType: P.Type = P.self,
        _ key: P.Key
    ) -> Value {
        shared.value(providerType, key)
    }
}
