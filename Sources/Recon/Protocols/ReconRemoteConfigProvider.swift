import Foundation
import Qalam

// Some provider like Firebase, Mobile Static etc
@MainActor
public protocol ReconRemoteConfigProvider {
    associatedtype Key: ReconConfigKey & CaseIterable

    /// Title visible in the UI
    var title: String { get }
    
    func refresh() async

    /// The value the provider itself serves, ignoring local overrides.
    /// Read through ``value(for:)`` instead; it applies overrides first.
    func providerValue(for key: Key) -> ReconConfigValue

    /// Where the provider's own value comes from, ignoring local overrides.
    func providerSource(for key: Key) -> ReconConfigSource
}

extension ReconRemoteConfigProvider {
    public var allKeys: [any ReconConfigKey] {
        Key.allCases.map { $0 as any ReconConfigKey }
    }
}

extension ReconRemoteConfigProvider {
    
    /// Callable on any ReconRemoteConfigProvider. Downcasts key, then
    /// dispatches to the concrete, generic addOverride.
    public func setOverride(for key: any ReconConfigKey, value: ReconConfigValue, in recon: Recon) {
        guard let typedKey = key as? Key else {
            Qalam.Log.console("key type mismatch on provider \(title)", .error, .named(system: "Recon"))
            return
        }
        recon.addOverride(provider: self, key: typedKey, value: value)
    }
    
    /// Callable on any ReconRemoteConfigProvider. Downcasts key, then
    /// dispatches to the concrete, generic removeOverride.
    public func removeOverride(for key: any ReconConfigKey, in recon: Recon) {
        guard let typedKey = key as? Key else {
            Qalam.Log.console("key type mismatch on provider \(title)", .error, .named(system: "Recon"))
            return
        }
        recon.removeOverride(provider: self, key: typedKey)
    }
}

extension ReconRemoteConfigProvider {

    /// Identifies this provider in Recon's override store.
    static var overrideIdentifier: String { String(describing: Self.self) }

    /// The raw value currently served for key: an active local override wins,
    /// otherwise the provider's own value.
    ///
    /// This is the core read every other accessor is built on. It's safe to
    /// call on a provider instance you already hold — the crash risk with
    /// Recon.shared.firebase.value(for:) comes from the .firebase accessor,
    /// not from this method.
    ///
    /// - Parameter key: The key to read.
    /// - Returns: The served value as a ``ReconConfigValue`` (never nil; the
    ///   wrapper's stringValue may be nil if nothing has been fetched).
    public func value(for key: Key) -> ReconConfigValue {
        Recon.shared.overrideValue(for: key, provider: Self.self) ?? providerValue(for: key)
    }

    /// Type-erased ``value(for:)`` for use with any ReconConfigKey, e.g. from
    /// the debug UI where the key type isn't statically known.
    /// - Returns: The served value, or nil if key doesn't belong to this
    ///   provider.
    public func anyValue(for key: any ReconConfigKey) -> ReconConfigValue? {
        guard let typedKey = key as? Key else { return nil }
        return value(for: typedKey) // now unambiguously calls the Key-typed method
    }

    /// Where key's current value comes from.
    /// - Returns: .override if a local override is active, otherwise whatever
    ///   ``providerSource(for:)`` reports (.remote / .local).
    public func source(for key: Key) -> ReconConfigSource {
        Recon.shared.overrideValue(for: key, provider: Self.self) != nil ? .override : providerSource(for: key)
    }

    /// Type-erased ``source(for:)`` for use with any ReconConfigKey.
    /// - Returns: The source, or nil if key doesn't belong to this provider.
    public func anySource(for key: any ReconConfigKey) -> ReconConfigSource? {
        guard let typedKey = key as? Key else { return nil }
        return source(for: typedKey) // calls the existing Key-typed method
    }

    public static var defaultValues: [String: String] {
        Dictionary(uniqueKeysWithValues: Key.allCases.compactMap { key in
            key.defaultValue.stringValue.map { (key.rawKey, $0) }
        })
    }

    /// Optional typed accessors on a provider instance.
    ///
    /// Call these when you already hold the provider (they're safe — no key path
    /// and no force-unwrap):
    ///
    ///swift
    /// let provider = FirebaseConfigProvider()
    /// let copy = provider.stringValue(for: .welcomeBannerCopy) ?? "Welcome!"
    ///

    ///
    /// Each returns `nil` when the value is absent or doesn't parse, so you
    /// supply the fallback. Unlike reading `value(for:).stringValue` directly,
    /// these verify the key is declared with the matching ``ReconConfigKey/expectedType``
    /// and log a warning on a type mismatch.
    ///
    /// - Note: For a non-optional read that auto-falls back to the key's default,
    ///   prefer ``Recon/value(_:_:)-(KeyPath<Recon,_>,_)`` or ``ReconFlag``.

    /// `key` as a `String`, or `nil` if absent. Logs a warning if `key` isn't `.string`.
    public func stringValue(for key: Key) -> String? {
        checkedValue(for: key, accessedAs: .string).stringValue
    }

    /// `key` as an `Int`, or `nil` if absent / unparseable. Logs a warning if `key` isn't `.int`.
    public func intValue(for key: Key) -> Int? {
        checkedValue(for: key, accessedAs: .int).intValue
    }

    /// `key` as a `Double`, or `nil` if absent / unparseable. Logs a warning if `key` isn't `.double`.
    public func doubleValue(for key: Key) -> Double? {
        checkedValue(for: key, accessedAs: .double).doubleValue
    }

    /// `key` as a `Bool`, or `nil` if absent / unparseable. Logs a warning if `key` isn't `.bool`.
    public func boolValue(for key: Key) -> Bool? {
        checkedValue(for: key, accessedAs: .bool).boolValue
    }

    /// `key` as a `Date` (ISO 8601), or `nil` if absent / unparseable. Logs a warning if `key` isn't `.date`.
    public func dateValue(for key: Key) -> Date? {
        checkedValue(for: key, accessedAs: .date).dateValue
    }

    /// `key` parsed as JSON (dictionary or array), or `nil` if absent / invalid. Logs a warning if `key` isn't `.json`.
    public func jsonValue(for key: Key) -> Any? {
        checkedValue(for: key, accessedAs: .json).jsonValue
    }

    /// `key` decoded from JSON into `T`, or `nil` if absent / decoding fails. Logs a warning if `key` isn't `.json`.
    ///
    /// ```swift
    /// let flags = provider.decodedValue(for: .featureFlagsJson, FeatureFlags.self)
    /// ```
    public func decodedValue<T: Decodable>(for key: Key, _ type: T.Type = T.self) -> T? {
        checkedValue(for: key, accessedAs: .json).decodedValue(type)
    }

    private func checkedValue(for key: Key, accessedAs type: ReconConfigValueType) -> ReconConfigValue {
        if key.expectedType != type {
            let message = "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(type.rawValue)"
            Qalam.Log.console(message, .error, .named(system: "Recon"))
        }
        return value(for: key)
    }

    /// Throws if the value currently served for `key` does not parse as the key's expected type.
    public func validate(_ key: Key) throws {
        // Get value for the key
        let value = value(for: key)
        
        // If the value doesnt match expected type, throw error.
        guard value.matches(key.expectedType) else {
            throw ConfigTypeMismatchError(mismatches: [
                .init(key: key.rawKey, expected: key.expectedType, rawValue: value.stringValue),
            ])
        }
    }

    /// Validates every key, collecting all mismatches into a single error.
    public func validateAll() throws {
        let mismatches = Key.allCases.compactMap { key -> ConfigTypeMismatchError.ReconMismatch? in
            let value = value(for: key)
            guard !value.matches(key.expectedType) else { return nil }
            return .init(key: key.rawKey, expected: key.expectedType, rawValue: value.stringValue)
        }
        guard mismatches.isEmpty else {
            throw ConfigTypeMismatchError(mismatches: mismatches)
        }
    }
}
