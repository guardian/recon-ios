import Foundation

/// Thrown by setOverrides(from:) when a serialized overrides string cannot
/// be parsed and applied.
public struct OverridesParseError: Error, CustomStringConvertible, Sendable {

    /// The line that could not be parsed, if the failure is line-specific.
    public let line: String?

    public init(line: String? = nil) {
        self.line = line
    }

    public var description: String {
        if let line {
            return "could not parse overrides line '\(line)'"
        }
        return "could not parse overrides string"
    }
}
