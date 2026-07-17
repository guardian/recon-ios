import Foundation

public enum ReconConfigValueType: String, Sendable, CaseIterable {
    case string
    case int
    case double
    case bool
    case date
    case json
}
