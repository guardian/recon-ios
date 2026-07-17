import Foundation

/// Denotes the source of the config.
/// This value can be used to determine whether the value fetched
/// by the app is the local default, remotely fetched or overriden.
public enum ReconConfigSource {
    case remote
    case local
    case override
}
