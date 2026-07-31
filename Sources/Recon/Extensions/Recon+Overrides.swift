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
            Qalam.Log.console("override for '\(key.rawKey)' does not parse as .\(key.expectedType.rawValue)", .error, .named(system: "Recon"))
        }
        overrides[P.overrideIdentifier, default: [:]][key.rawKey] = raw
        persistOverrides()
    }

    public func addOverride<P: ReconRemoteConfigProvider>(provider: P, key: P.Key, value: ReconConfigValue) {
            guard let raw = value.stringValue else {
                return
            }
            if !value.matches(key.expectedType) {
                Qalam.Log.console("override for '\(key.rawKey)' does not parse as .\(key.expectedType.rawValue)", .error, .named(system: "Recon"))
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

    /// Serializes every active override to a single string, suitable for
    /// sharing or persisting elsewhere. Feed the result back to
    /// ``setOverrides(from:)`` to restore the same overrides.
    public func getOverrides() -> String {
        overrides
            .sorted { $0.key < $1.key }
            .flatMap { provider, keyValues in
                keyValues.sorted { $0.key < $1.key }.map { key, value in
                    [provider, key, value].joined(separator: "$")
                }
            }
            .joined(separator: "&")
    }

    /// Applies overrides from a string produced by ``getOverrides()``,
    /// replacing any currently active overrides. Throws
    /// ``OverridesParseError`` if the string could not be parsed, in which
    /// case the current overrides are left unchanged.
    public func setOverrides(from string: String) throws {
        var decoded: [String: [String: String]] = [:]
        let lines = string.split(separator: "&", omittingEmptySubsequences: true)
        for line in lines {
            let fields = line.split(separator: "$", omittingEmptySubsequences: false)
            guard fields.count == 3 else {
                let error = OverridesParseError(line: String(line))
                Qalam.Log.console(error.description, .error, .named(system: "Recon"))
                throw error
            }
            let provider = String(fields[0])
            let key = String(fields[1])
            let value = String(fields[2])
            decoded[provider, default: [:]][key] = value
        }
        overrides = decoded
        persistOverrides()
        Qalam.Log.console("Overrides applied: \(overrides)", .info, .named(system: "Recon"))
    }

    private func persistOverrides() {
        UserDefaults.standard.set(overrides, forKey: Self.overridesDefaultsKey)
    }
}
