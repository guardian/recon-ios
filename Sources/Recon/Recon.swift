import Foundation

@MainActor
public final class Recon {

    public static let shared: Recon = .init()

    var remoteConfigProviders: [any ReconRemoteConfigProvider]

    private init() {
        self.remoteConfigProviders = []
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
