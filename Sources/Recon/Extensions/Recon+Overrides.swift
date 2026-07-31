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

    /// Serializes every active override to a single-line string, suitable for
        /// sharing or persisting elsewhere. Overrides are joined with &, each one
        /// a provider|key|value triple. Fields are percent-encoded so ordinary
        /// flag names and values stay human-readable and only characters that would
        /// collide with the delimiters (|, &, %) are escaped. Feed the result
        /// back to ``setOverrides(from:)`` to restore the same overrides.
        public func getOverrides() -> String {
            overrides
                .sorted { $0.key < $1.key }
                .flatMap { provider, keyValues in
                    keyValues.sorted { $0.key < $1.key }.map { key, value in
                        [provider, key, value].map(Self.encodeField).joined(separator: "|")
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
            let entries = string.split(separator: "&", omittingEmptySubsequences: true)
            for entry in entries {
                let fields = entry.split(separator: "|", omittingEmptySubsequences: false)
                guard fields.count == 3,
                      let provider = Self.decodeField(String(fields[0])),
                      let key = Self.decodeField(String(fields[1])),
                      let value = Self.decodeField(String(fields[2])) else {
                    let error = OverridesParseError(entry: String(entry))
                    Qalam.Log.console(error.description, .error, .named(system: "Recon"))
                    throw error
                }
                decoded[provider, default: [:]][key] = value
            }
            overrides = decoded
            persistOverrides()
        }

        /// Characters left unescaped in a serialized field: everything URL query
        /// allows except the delimiters (|) and separators (=, &) so fields
        /// stay readable while never colliding with the line format. % and
        /// newlines fall outside this set and are always escaped.
        private static let fieldAllowed: CharacterSet = {
            var set = CharacterSet.urlQueryAllowed
            set.remove(charactersIn: "|=&")
            return set
        }()

        private static func encodeField(_ field: String) -> String {
            field.addingPercentEncoding(withAllowedCharacters: fieldAllowed) ?? field
        }

        private static func decodeField(_ field: String) -> String? {
            field.removingPercentEncoding
        }

    private func persistOverrides() {
        UserDefaults.standard.set(overrides, forKey: Self.overridesDefaultsKey)
    }
}
