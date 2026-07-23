@testable import Recon

internal enum WellFormedKey: String, CaseIterable, ReconConfigKey {
    case stringFlag = "string_flag"
    case intFlag = "int_flag"
    case doubleFlag = "double_flag"
    case boolFlag = "bool_flag"
    case dateFlag = "date_flag"
    case jsonFlag = "json_flag"

    var defaultValue: ReconConfigValue {
        switch self {
        case .stringFlag: "hello"
        case .intFlag: 42
        case .doubleFlag: 3.14
        case .boolFlag: true
        case .dateFlag: "2026-01-01T00:00:00Z"
        case .jsonFlag: "{\"a\":1}"
        }
    }

    var expectedType: ReconConfigValueType {
        switch self {
        case .stringFlag: .string
        case .intFlag: .int
        case .doubleFlag: .double
        case .boolFlag: .bool
        case .dateFlag: .date
        case .jsonFlag: .json
        }
    }
}

internal struct WellFormedProvider: ReconRemoteConfigProvider {
    let title = "WellFormed"
    func refresh() async {}
    func providerValue(for key: WellFormedKey) -> ReconConfigValue { key.defaultValue }
    func providerSource(for key: WellFormedKey) -> ReconConfigSource { .local }
}
