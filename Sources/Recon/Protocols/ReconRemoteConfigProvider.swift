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

    /// Identifies this provider in Recon's override store.
    static var overrideIdentifier: String { String(describing: Self.self) }

    /// The value currently served for `key`: an active local override wins,
    /// otherwise the provider's own value.
    public func value(for key: Key) -> ReconConfigValue {
        Recon.shared.overrideValue(for: key, provider: Self.self) ?? providerValue(for: key)
    }

    public func anyValue(for key: any ReconConfigKey) -> ReconConfigValue? {
        guard let typedKey = key as? Key else { return nil }
        return value(for: typedKey) // now unambiguously calls the Key-typed method
    }
    
    public func source(for key: Key) -> ReconConfigSource {
        Recon.shared.overrideValue(for: key, provider: Self.self) != nil ? .override : providerSource(for: key)
    }

    public static var defaultValues: [String: String] {
        Dictionary(uniqueKeysWithValues: Key.allCases.compactMap { key in
            key.defaultValue.stringValue.map { (key.rawKey, $0) }
        })
    }

    /// Typed accessors. Unlike `value(for:).stringValue` etc., these check that
    /// the key is actually declared with the matching expected type: accessing a
    /// key through the wrong type logs a warning and asserts in debug builds.

    public func stringValue(for key: Key) -> String? {
        checkedValue(for: key, accessedAs: .string).stringValue
    }

    public func intValue(for key: Key) -> Int? {
        checkedValue(for: key, accessedAs: .int).intValue
    }

    public func doubleValue(for key: Key) -> Double? {
        checkedValue(for: key, accessedAs: .double).doubleValue
    }

    public func boolValue(for key: Key) -> Bool? {
        checkedValue(for: key, accessedAs: .bool).boolValue
    }

    public func dateValue(for key: Key) -> Date? {
        checkedValue(for: key, accessedAs: .date).dateValue
    }

    public func jsonValue(for key: Key) -> Any? {
        checkedValue(for: key, accessedAs: .json).jsonValue
    }

    public func decodedValue<T: Decodable>(for key: Key, _ type: T.Type = T.self) -> T? {
        checkedValue(for: key, accessedAs: .json).decodedValue(type)
    }

    private func checkedValue(for key: Key, accessedAs type: ReconConfigValueType) -> ReconConfigValue {
        if key.expectedType != type {
            let message = "'\(key.rawKey)' is declared as .\(key.expectedType.rawValue) but was accessed as .\(type.rawValue)"
            Log.error(message, .named("Recon"))
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
