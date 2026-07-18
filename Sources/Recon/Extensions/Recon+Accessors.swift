import Foundation

/// Typed accessors addressed by provider key path, so call sites don't have to
/// go through the provider:
///
///     Recon.shared.boolValue(\.firebase, .isEnabled)
///
/// These forward to the provider's accessors, so expected-type checking
/// behaves the same as `provider.boolValue(for:)` etc.
extension Recon {

    public func value<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> ReconConfigValue {
        self[keyPath: providerPath].value(for: key)
    }

    public func source<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> ReconConfigSource {
        self[keyPath: providerPath].source(for: key)
    }

    public func stringValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> String? {
        self[keyPath: providerPath].stringValue(for: key)
    }

    public func intValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Int? {
        self[keyPath: providerPath].intValue(for: key)
    }

    public func doubleValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Double? {
        self[keyPath: providerPath].doubleValue(for: key)
    }

    public func boolValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Bool? {
        self[keyPath: providerPath].boolValue(for: key)
    }

    public func dateValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Date? {
        self[keyPath: providerPath].dateValue(for: key)
    }

    public func jsonValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> Any? {
        self[keyPath: providerPath].jsonValue(for: key)
    }

    public func decodedValue<P: ReconRemoteConfigProvider, T: Decodable>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key, _ type: T.Type = T.self) -> T? {
        self[keyPath: providerPath].decodedValue(for: key, type)
    }
}
