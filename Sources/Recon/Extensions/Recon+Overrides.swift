import Foundation
import Qalam

/// Local overrides, e.g. `Recon.shared.addOverride(\.firebase, .isEnabled, false)`.
/// An active override wins over whatever the provider would serve, and is
/// persisted in UserDefaults until removed.
extension Recon {

    public func addOverride<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key, _ value: ReconConfigValue) {
        guard let raw = value.stringValue else {
            removeOverride(providerPath, key)
            return
        }
        if !value.matches(key.expectedType) {
            Qalam.Log.error("override for '\(key.rawKey)' does not parse as .\(key.expectedType.rawValue)", .named("Recon"))
        }
        overrides[P.overrideIdentifier, default: [:]][key.rawKey] = raw
        persistOverrides()
    }

    public func addOverride<P: ReconRemoteConfigProvider>(provider: P, key: P.Key, value: ReconConfigValue) {
            guard let raw = value.stringValue else {
                return
            }
            if !value.matches(key.expectedType) {
                Qalam.Log.error("override for '\(key.rawKey)' does not parse as .\(key.expectedType.rawValue)", .named("Recon"))
            }
            overrides[P.overrideIdentifier, default: [:]][key.rawKey] = raw
            persistOverrides()
        }
    
    public func removeOverride<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) {
        overrides[P.overrideIdentifier]?[key.rawKey] = nil
        persistOverrides()
    }

    public func removeOverride<P: ReconRemoteConfigProvider>(provider: P, key: P.Key) {
        overrides[P.overrideIdentifier]?[key.rawKey] = nil
        persistOverrides()
    }

    /// Removes every override for the provider.
    public func clearOverrides<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>) {
        overrides[P.overrideIdentifier] = nil
        persistOverrides()
    }

    /// The active override for `key`, if any.
    public func overrideValue<P: ReconRemoteConfigProvider>(_ providerPath: KeyPath<Recon, P>, _ key: P.Key) -> ReconConfigValue? {
        overrideValue(for: key, provider: P.self)
    }

    /// Lookup used by ``ReconRemoteConfigProvider``'s `value(for:)`/`source(for:)`.
    func overrideValue<P: ReconRemoteConfigProvider>(for key: P.Key, provider: P.Type) -> ReconConfigValue? {
        overrides[P.overrideIdentifier]?[key.rawKey].map(ReconConfigValue.init)
    }

    private func persistOverrides() {
        UserDefaults.standard.set(overrides, forKey: Self.overridesDefaultsKey)
    }
}
