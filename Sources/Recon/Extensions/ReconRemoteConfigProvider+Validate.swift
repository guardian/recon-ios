import Foundation

extension ReconRemoteConfigProvider {

    /// Throws if key's own default value does not parse as its expected type,
    /// independent of anything a provider or override currently serves.
    public static func validateDefaultValue(_ key: Key) throws {
        guard key.defaultValue.matches(key.expectedType) else {
            throw ConfigTypeMismatchError(mismatches: [
                .init(key: key.rawKey, expected: key.expectedType, rawValue: key.defaultValue.stringValue),
            ])
        }
    }

    /// Validates every key's default value, collecting all mismatches into a single error.
    public static func validateDefaultValues() throws {
        let mismatches = Key.allCases.compactMap { key -> ConfigTypeMismatchError.ReconMismatch? in
            guard !key.defaultValue.matches(key.expectedType) else { return nil }
            return .init(key: key.rawKey, expected: key.expectedType, rawValue: key.defaultValue.stringValue)
        }
        guard mismatches.isEmpty else {
            throw ConfigTypeMismatchError(mismatches: mismatches)
        }
    }
}
