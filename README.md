# 🔭 Recon
 
**Type-safe remote config & feature flags for iOS, with a built-in debug UI for overriding values on-device.**
 
[![Swift](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platform-iOS%2018%2B-blue)](#requirements)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)](#installation)
 
Recon sits between your app and whatever remote config backend you use (Firebase Remote Config, a homegrown JSON endpoint, LaunchDarkly, etc.), giving you:
 
- a single, provider-agnostic API to read config values (`Recon.shared`, `@ReconFlag`)
- **compile-time-safe keys**, generated from a plist so the plist is always the source of truth
- **on-device local overrides** that persist across launches, for QA and debugging
- a drop-in **SwiftUI debug screen** to browse, search, and override every flag
- type mismatch detection between what a key declares and how it's actually used
Recon does not talk to any network itself — it defines the contract (`ReconRemoteConfigProvider`) that your Firebase/whatever integration implements, and handles storage, overrides, typing, and UI on top.
 
---
 
## Contents
 
- [How it fits together](#how-it-fits-together)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
  - [1. Declare your keys](#1-declare-your-keys)
  - [2. Implement a provider](#2-implement-a-provider)
  - [3. Register the provider](#3-register-the-provider)
  - [4. Read values](#4-read-values)
- [Code generation (`recon-keygen`)](#code-generation-recon-keygen)
- [Local overrides & the debug UI](#local-overrides--the-debug-ui)
- [Validating config at startup](#validating-config-at-startup)
- [Testing](#testing)
- [Project layout](#project-layout)
---
 
## How it fits together
 
| Piece | What it does |
|---|---|
| `Recon` | The shared singleton (`Recon.shared`). Holds registered providers and persisted local overrides. |
| `ReconRemoteConfigProvider` | Protocol your remote config backend conforms to — e.g. a `FirebaseConfigProvider`. Supplies raw values and lets Recon layer overrides + typed accessors on top. |
| `ReconConfigKey` | Protocol for a config key: its raw backend name, default value, and expected type. Usually an enum, one per provider. |
| `ReconConfigValue` | A provider-agnostic wrapper around a raw string, with typed accessors (`.stringValue`, `.intValue`, `.boolValue`, `.dateValue`, `.jsonValue`, `.decodedValue()`). |
| `@ReconFlag` | Property wrapper for reading a flag as a plain typed property. |
| `ReconConfigListView` | SwiftUI screen listing every key per provider, with search and inline override editing. |
| `recon-keygen` / `ReconKeygenPlugin` | A build plugin that turns a `*.rcf.plist` file into a generated `ReconConfigKey` enum, so you never hand-write keys or defaults. |
 
## Requirements
 
- iOS 18+
- Swift 6.3 / Swift tools 6.3 (Swift 6 language mode)
- Xcode with Swift Package Manager support
## Installation
 
Add Recon as a package dependency, either via Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:
 
```swift
dependencies: [
    .package(url: "https://github.com/guardian/recon-ios", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Recon", package: "recon-ios"),
        ]
    ),
]
```
 
If you want compile-time-generated keys (recommended), also add the build tool plugin to the target that owns your `*.rcf.plist` files:
 
```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Recon", package: "recon-ios"),
    ],
    plugins: [
        .plugin(name: "ReconKeygenPlugin", package: "recon-ios"),
    ]
)
```
 
## Quick start
 
### 1. Declare your keys
 
The easiest way is to let the keygen plugin generate the enum for you (see [Code generation](#code-generation-recon-keygen) below). If you'd rather write it by hand, a key just needs to conform to `ReconConfigKey`:
 
```swift
import Recon
 
enum FirebaseKey: String, ReconConfigKey, CaseIterable {
    case isCheckoutV2Enabled
    case maxRetryCount
    case welcomeBannerCopy
 
    var defaultValue: ReconConfigValue {
        switch self {
        case .isCheckoutV2Enabled: return false
        case .maxRetryCount:       return 3
        case .welcomeBannerCopy:   return "Welcome!"
        }
    }
 
    var expectedType: ReconConfigValueType {
        switch self {
        case .isCheckoutV2Enabled: return .bool
        case .maxRetryCount:       return .int
        case .welcomeBannerCopy:   return .string
        }
    }
}
```
 
### 2. Implement a provider
 
Wrap whatever backend you use behind `ReconRemoteConfigProvider`. This is the only piece of Recon that talks to the network.
 
```swift
import Recon
import FirebaseRemoteConfig
 
@MainActor
final class FirebaseConfigProvider: ReconRemoteConfigProvider {
    typealias Key = FirebaseKey
 
    let title = "Firebase"
    private let remoteConfig = RemoteConfig.remoteConfig()
 
    func refresh() async {
        try? await remoteConfig.fetchAndActivate()
    }
 
    func providerValue(for key: Key) -> ReconConfigValue {
        ReconConfigValue(remoteConfig[key.rawKey].stringValue)
    }
 
    func providerSource(for key: Key) -> ReconConfigSource {
        remoteConfig[key.rawKey].source == .remote ? .remote : .local
    }
}
```
 
### 3. Register the provider
 
Do this once, e.g. in your `App` init or `AppDelegate`. Registering triggers an initial `refresh()`.
 
```swift
Recon.shared.addRemoteConfigProvider(FirebaseConfigProvider())
```
 
For ergonomic call sites, expose the provider as a `Recon` extension:
 
```swift
extension Recon {
    var firebase: FirebaseConfigProvider { provider(FirebaseConfigProvider.self)! }
}
```
 
### 4. Read values
 
Three ways to read a flag, pick whichever fits the call site:
 
```swift
// Property wrapper — reads live, no boilerplate at the call site.
struct CheckoutView: View {
    @ReconFlag(\.firebase, .isCheckoutV2Enabled) private var isV2Enabled: Bool
 
    var body: some View {
        isV2Enabled ? CheckoutV2() : CheckoutV1()
    }
}
 
// KeyPath-based accessor on the shared instance.
let retries = Recon.shared.intValue(\.firebase, .maxRetryCount) ?? 3
 
// Directly on the provider.
let copy = Recon.shared.firebase.stringValue(for: .welcomeBannerCopy)
```
 
Typed accessors (`stringValue`, `intValue`, `doubleValue`, `boolValue`, `dateValue`, `jsonValue`, `decodedValue(_:)`) log a warning if you read a key using a type that doesn't match its declared `expectedType`, so a `.string` key silently misused as `.int` shows up in your logs instead of failing quietly.
 
JSON-backed keys can decode straight into a model — just make it `Decodable` and opt in:
 
```swift
struct FeatureFlags: Decodable, ConfigDecodable {}
 
let flags = Recon.shared.decodedValue(\.firebase, .featureFlagsJson, FeatureFlags.self)
```
 
## Code generation (`recon-keygen`)
 
Rather than hand-writing key enums, drop a plist named `<EnumName>.rcf.plist` anywhere in a target that has `ReconKeygenPlugin` attached. Its keys and default values become the source of truth; the plugin regenerates a `<EnumName>Key` enum on every build.
 
`Firebase.rcf.plist`:
 
```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>isCheckoutV2Enabled</key>
    <false/>
    <key>maxRetryCount</key>
    <integer>3</integer>
    <key>welcomeBannerCopy</key>
    <string>Welcome!</string>
    <key>featureFlagsJson</key>
    <string>{"newOnboarding": true}</string>
</dict>
</plist>
```
 
generates a `FirebaseKey` enum equivalent to the hand-written one above — snake_case entries become `camelCase` cases, and the value's native plist type (`string`/`integer`/`real`/`boolean`/`date`, or a `{…}`/`[…]` string that must itself parse as JSON) picks `expectedType` automatically.
 
Flags can also carry an expiry, which surfaces as an Xcode build warning once passed:
 
```xml
<key>oldMigrationFlag</key>
<dict>
    <key>value</key><false/>
    <key>expires</key><date>2026-01-01T00:00:00Z</date>
</dict>
```

 ------
 Thank you for using Recon!
 iOS Team, The Guardian
