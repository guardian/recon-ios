import Foundation
import Qalam

@MainActor
public final class Recon {

    public static let shared: Recon = .init()

    /// UserDefaults key under which local overrides persist across launches.
    static let overridesDefaultsKey = "recon.overrides"

    var remoteConfigProviders: [any ReconRemoteConfigProvider]

    /// Local overrides, keyed by provider identifier then raw key, mirrored
    /// to UserDefaults. While a key has an override, reads return it instead
    /// of the provider's value and `source(for:)` reports `.override`.
    var overrides: [String: [String: String]]

    private init() {
        self.remoteConfigProviders = []
        self.overrides = UserDefaults.standard.dictionary(forKey: Self.overridesDefaultsKey) as? [String: [String: String]] ?? [:]
    }

    /// Add a new provider and fetch its key:values
    public func addRemoteConfigProvider(_ provider: some ReconRemoteConfigProvider) {
        self.remoteConfigProviders.append(provider)
        Task { await provider.refresh() }
    }

    /// Used to get a provider that can give the value.
    public func provider<P: ReconRemoteConfigProvider>(_ type: P.Type = P.self) -> P? {
        remoteConfigProviders.lazy.compactMap { $0 as? P }.first
    }
}
