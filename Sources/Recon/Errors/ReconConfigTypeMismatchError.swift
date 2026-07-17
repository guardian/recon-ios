import Foundation

/// Thrown when served values do not parse as their key's expected type.
public struct ConfigTypeMismatchError: Error, CustomStringConvertible, Sendable {

    public struct ReconMismatch: Sendable {
        public let key: String
        public let expected: ReconConfigValueType
        public let rawValue: String?
    }

    public let mismatches: [ReconMismatch]

    public var description: String {
        mismatches
            .map { "key '\($0.key)' expected \($0.expected.rawValue), got \($0.rawValue.map { "\"\($0)\"" } ?? "nil")" }
            .joined(separator: "; ")
    }
}
