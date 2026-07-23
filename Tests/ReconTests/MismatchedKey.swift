@testable import Recon

internal enum MismatchedKey: String, CaseIterable, ReconConfigKey {
    case brokenInt = "broken_int"
    case brokenDouble = "broken_double"
    case brokenBool = "broken_bool"
    case brokenDate = "broken_date"
    case brokenJSONSyntax = "broken_json_syntax"   // malformed JSON (unquoted key)
    case brokenJSONNotAnObject = "broken_json_not_object" // valid JSON scalar, not parseable as expected structure
    case okString = "ok_string"

    var defaultValue: ReconConfigValue {
        switch self {
        case .brokenInt: "not-a-number"
        case .brokenDouble: "not-a-double"
        case .brokenBool: "maybe" // not "true"/"false"/"1"/"0"/"yes"/"no" etc.
        case .brokenDate: "not-a-real-date"
        case .brokenJSONSyntax: "{a:1}" // missing quotes around key — invalid JSON
        case .brokenJSONNotAnObject: "\"just a string\"" // valid JSON, but likely not what json-type expects
        case .okString: "fine"
        }
    }

    var expectedType: ReconConfigValueType {
        switch self {
        case .brokenInt: .int
        case .brokenDouble: .double
        case .brokenBool: .bool
        case .brokenDate: .date
        case .brokenJSONSyntax: .json
        case .brokenJSONNotAnObject: .json
        case .okString: .string
        }
    }
}

internal struct MismatchedProvider: ReconRemoteConfigProvider {
    let title = "Mismatched"
    func refresh() async {}
    func providerValue(for key: MismatchedKey) -> ReconConfigValue { key.defaultValue }
    func providerSource(for key: MismatchedKey) -> ReconConfigSource { .local }
}
