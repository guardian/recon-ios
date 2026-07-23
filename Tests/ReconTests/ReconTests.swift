import Testing
@testable import Recon

// MARK: - Happy path
@Test @MainActor func wellFormedProviderDefaultsMatchExpectedType() throws {
    try WellFormedProvider.validateDefaultValues()
}

// MARK: - Mismatch detection, one per type
@Test @MainActor func mismatchedProviderDefaultsAreCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValues()
    }
}

@Test @MainActor func intMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenInt)
    }
}

@Test @MainActor func doubleMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenDouble)
    }
}

@Test @MainActor func boolMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenBool)
    }
}

@Test @MainActor func dateMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenDate)
    }
}

@Test @MainActor func jsonSyntaxMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenJSONSyntax)
    }
}

@Test @MainActor func jsonNonObjectMismatchIsCaught() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenJSONNotAnObject)
    }
}

// MARK: - Isolation: validating one broken key doesn't flag the good ones
@Test @MainActor func mismatchReportsOnlyTheBrokenKey() {
    #expect(throws: ConfigTypeMismatchError.self) {
        try MismatchedProvider.validateDefaultValue(.brokenInt)
    }
    #expect(throws: Never.self) {
        try MismatchedProvider.validateDefaultValue(.okString)
    }
}
