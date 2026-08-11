import Foundation
import Qalam

@MainActor
@Observable
public final class Recon {

    public static let shared: Recon = .init()

    /// UserDefaults key under which local overrides persist across launches.
    static let overridesDefaultsKey = "recon.overrides"

    var remoteConfigProviders: [any ReconRemoteConfigProvider]

    /// Denotes whether all the remote config providers have been refreshed and are ready for use.
    public private(set) var isSynced: Bool = false

    /// Local overrides, keyed by provider identifier then raw key, mirrored
    /// to UserDefaults. While a key has an override, reads return it instead
    /// of the provider's value and `source(for:)` reports `.override`.
    var overrides: [String: [String: String]]

    private init() {
        self.remoteConfigProviders = []
        self.overrides = UserDefaults.standard.dictionary(forKey: Self.overridesDefaultsKey) as? [String: [String: String]] ?? [:]
    }

    /// Refreshes remote configs for all providers and sets Recon's ready status by setting `isEnabled = true`.
    /// Call this after adding all providers. Until this is called, all reads will return default values.
    public func sync() async {
        let sendableProviders = remoteConfigProviders.map(SendableProvider.init)
        await withTaskGroup(of: Void.self) { group in
            for sendableProvider in sendableProviders {
                group.addTask {
                    await sendableProvider.rcp.refresh()
                }
            }
        }
        isSynced = true
    }

    /// Add a new provider and fetch its key:values
    /// - Parameters:
    ///   - provider: Remote config provider.
    ///   - autoSync: Should the provider be refreshed immediately after being added. Defaults to false.
    public func addRemoteConfigProvider(_ provider: some ReconRemoteConfigProvider, autoSync: Bool = false) async {
        self.remoteConfigProviders.append(provider)
        if autoSync { await provider.refresh() }
    }

    /// Used to get a provider that can give the value.
    public func provider<P: ReconRemoteConfigProvider>(_ type: P.Type = P.self) -> P? {
        remoteConfigProviders.lazy.compactMap { $0 as? P }.first
    }
}

internal struct SendableProvider: @unchecked Sendable {
    let rcp: any ReconRemoteConfigProvider
}
