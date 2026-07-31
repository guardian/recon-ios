import Foundation

/// Thrown by setOverrides(from:) when a serialized overrides string cannot
/// be parsed and applied.
public struct OverridesParseError: Error, CustomStringConvertible, Sendable {

    /// The provider|key|value entry that could not be parsed, if the failure
    /// is entry-specific.
    public let entry: String?

    public init(entry: String? = nil) {
        self.entry = entry
    }

    public var description: String {
        if let entry {
            return "could not parse overrides entry '\(entry)'"
        }
        return "could not parse overrides string"
    }
}
