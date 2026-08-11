import Foundation

/// Optional typed accessors addressed by provider key path.
///
/// Use these when you specifically need to distinguish "no value / didn't
/// parse" (they return nil) from a real value, and want to supply your own
/// fallback:
///
///swift
/// let retries = Recon.shared.intValue(\.firebase, .maxRetryCount) ?? 3
///

///
/// For the common case — a value that should always resolve — prefer the
/// non-optional ``value(_:_:)-(KeyPath<Recon,_>,_)``, which falls back to the
/// key's declared default automatically.
///
/// - Warning: These resolve the provider by subscripting the key path (e.g.
///   `\.firebase`), which runs **your** provider accessor. If that accessor
///   force-unwraps (`provider(FirebaseConfigProvider.self)!`, as in the README
///   example) it will **crash when the provider isn't registered yet** — e.g.
///   in SwiftUI previews, tests, or reads that run before
///   ``Recon/addRemoteConfigProvider(_:)``. ``ReconFlag`` and
///   ``value(_:_:)-(KeyPath<Recon,_>,_)`` don't have this problem because they
///   resolve by type with a default fallback.
///
/// Each accessor forwards to the provider's matching accessor, so expected-type
/// checking behaves the same as `provider.boolValue(for:)` etc. (a mismatched
/// type logs a warning).
extension Recon {

    /// The raw served value for `key` (an active override, otherwise the
    /// provider's value).
    /// - Returns: A ``ReconConfigValue`` wrapping the served string.
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func value<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> ReconConfigValue {
        self[keyPath: providerPath].value(for: key)
    }

    /// Where `key`'s current value comes from (`.remote`, `.local`, or `.override`).
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func source<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> ReconConfigSource {
        self[keyPath: providerPath].source(for: key)
    }

    /// `key` as a `String`, or `nil` if absent.
    ///
    /// ```swift
    /// let copy = Recon.shared.stringValue(\.firebase, .welcomeBannerCopy) ?? "Welcome!"
    /// ```
    ///
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func stringValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> String? {
        self[keyPath: providerPath].stringValue(for: key)
    }

    /// `key` as an `Int`, or `nil` if absent / unparseable.
    ///
    /// ```swift
    /// let retries = Recon.shared.intValue(\.firebase, .maxRetryCount) ?? 3
    /// ```
    ///
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func intValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Int? {
        self[keyPath: providerPath].intValue(for: key)
    }

    /// `key` as a `Double`, or `nil` if absent / unparseable.
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func doubleValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Double? {
        self[keyPath: providerPath].doubleValue(for: key)
    }

    /// `key` as a `Bool`, or `nil` if absent / unparseable.
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func boolValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Bool? {
        self[keyPath: providerPath].boolValue(for: key)
    }

    /// `key` as a `Date` (ISO 8601), or `nil` if absent / unparseable.
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func dateValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Date? {
        self[keyPath: providerPath].dateValue(for: key)
    }

    /// `key` parsed as JSON (dictionary or array), or `nil` if absent / invalid.
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func jsonValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Any? {
        self[keyPath: providerPath].jsonValue(for: key)
    }

    /// `key` decoded from JSON into `T`, or `nil` if absent / decoding fails.
    ///
    /// ```swift
    /// let flags = Recon.shared.decodedValue(\.firebase, .featureFlagsJson, FeatureFlags.self)
    /// ```
    ///
    /// - Warning: Traps if the provider isn't registered and your key-path
    ///   accessor force-unwraps. See the type overview.
    public func decodedValue<P: ReconRemoteConfigProvider, T: Decodable>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key, _ type: T.Type = T.self) -> T? {
        self[keyPath: providerPath].decodedValue(for: key, type)
    }
}
