<img height="70" alt="Recon" src="https://github.com/user-attachments/assets/122e62d3-0c66-4470-b588-ed2b819a5902" />

**Type-safe remote config and feature flags for iOS, with a built-in debug UI for overriding values on-device.**

[![Swift](https://img.shields.io/badge/Swift-6.3-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platform-iOS%2018%2B-blue)](#requirements)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)](#installation)

Recon sits between your app and whatever remote config backend you use — Firebase Remote Config, a homegrown JSON endpoint, LaunchDarkly — and gives you:

- **A provider-agnostic API** for reading config values (`Recon.shared`, `@ReconFlag`)
- **Compile-time-safe keys**, generated from a plist so the plist stays the source of truth
- **On-device local overrides** that persist across launches, for QA and debugging
- **A drop-in SwiftUI debug screen** to browse, search, and override every flag

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
- [Code generation (recon-keygen)](#code-generation-recon-keygen)
- [Local overrides and the debug UI](#local-overrides-and-the-debug-ui)
  - [Setting overrides in code](#setting-overrides-in-code)
  - [The debug screen](#the-debug-screen)
  - [Exporting and importing overrides](#exporting-and-importing-overrides)
- [Validating config at startup](#validating-config-at-startup)
- [Testing](#testing)
- [Project layout](#project-layout)

---

## How it fits together

| Piece | What it does |
| --- | --- |
| `Recon` | The shared singleton (`Recon.shared`). Holds registered providers and persisted local overrides. |
| `ReconRemoteConfigProvider` | Protocol your remote config backend conforms to — e.g. a `FirebaseConfigProvider`. Supplies raw values so Recon can layer overrides and typed accessors on top. |
| `ReconConfigKey` | Protocol for a config key: its raw backend name, default value, and expected type. Usually an enum, one per provider. |
| `ReconConfigValue` | A provider-agnostic wrapper around a raw string, with typed accessors (`.stringValue`, `.intValue`, `.boolValue`, `.dateValue`, `.jsonValue`, `.decodedValue()`). |
| `@ReconFlag` | Property wrapper for reading a flag as a plain typed property. |
| `ReconConfigListView` | SwiftUI screen listing every key per provider, with search and inline override editing. |
| `recon-keygen` / `ReconKeygenPlugin` | Build plugin that turns a `*.rcf.plist` file into a generated `ReconConfigKey` enum, so you never hand-write keys or defaults. |

---

## Requirements

- iOS 18+
- Swift 6.3 / Swift tools 6.3 (Swift 6 language mode)
- Xcode with Swift Package Manager support

---

## Installation

Add Recon as a package dependency via Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:

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

For compile-time-generated keys (recommended), also attach the build tool plugin to the target that owns your `*.rcf.plist` files:

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

---

## Quick start

### 1. Declare your keys

The easiest route is to let the keygen plugin generate the enum for you — see [Code generation](#code-generation-recon-keygen). To write one by hand, conform to `ReconConfigKey`:

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

> `ReconConfigValue` is `ExpressibleBy{String,Integer,Float,Boolean}Literal`, so defaults can be written as plain literals (`false`, `3`, `"Welcome!"`) rather than `ReconConfigValue(...)`. Every value is stored as a raw string under the hood; `expectedType` is what the typed accessors and validation check against.

### 2. Implement a provider

Wrap your backend behind `ReconRemoteConfigProvider`. This is the only piece of Recon that talks to the network.

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

Do this once, in your `App` init or `AppDelegate`. Registering triggers an initial `refresh()`.

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

There are four ways to read a flag. Pick by call site:

| Call site | Use |
| --- | --- |
| A SwiftUI view or any stored property | `@ReconFlag` |
| A one-off read that should never fail | `Recon.value(_:_:)` |
| You need to know the value was missing | `intValue`, `stringValue`, … |
| You already have the provider in hand | `provider.stringValue(for:)` |

Code example:

```swift
// Property wrapper — reads live, no boilerplate at the call site.
struct CheckoutView: View {
    @ReconFlag(\.firebase, .isCheckoutV2Enabled) private var isV2Enabled: Bool

    var body: some View {
        isV2Enabled ? CheckoutV2() : CheckoutV1()
    }
}

// Non-optional typed read — falls back to the key's own default,
// so there's no `?? default` to write.
let isV2Enabled: Bool = Recon.value(\.firebase, .isCheckoutV2Enabled)
let retries: Int = Recon.shared.value(\.firebase, .maxRetryCount)

// Optional typed accessor — nil when the served value is absent or
// doesn't parse, so you supply the fallback yourself.
let maybeRetries = Recon.shared.intValue(\.firebase, .maxRetryCount) ?? 3

// Directly on the provider.
let copy = Recon.shared.firebase.stringValue(for: .welcomeBannerCopy)
```

``Recon/value(_:_:)`` and its instance form ``Recon/shared`` parse the served
value as the annotated type, falling back to the key's declared
``ReconKey/defaultValue`` whenever the provider isn't registered or the value
doesn't parse. That's what makes the result non-optional and crash-safe.

The type annotation is required, because the result type is what selects `Bool`
over `Int`:

```swift
// If using on main actor
let x: Bool = Recon.value(\.firebase, .isCheckoutV2Enabled)  // ✅
let x = Recon.value(\.firebase, .isCheckoutV2Enabled)        // ❌ won't compile

// If using off main actor
let x: Bool = Recon.value(FirebaseRCP.self, .isCheckoutV2Enabled)  // ✅
let x = Recon.value(FirebaseRCP.self, .isCheckoutV2Enabled)        // ❌ won't compile
```

> [!IMPORTANT]
> **The key-path form is main-actor-only.** `\.firebase` is a key path to a
> main-actor-isolated provider accessor, and forming one is only legal from the
> main actor. Reads go through ``Recon`` on the main actor anyway (the class is
> `@MainActor`), so on the main actor the key path is the ergonomic choice.
>
> From inside an actor or any other non-main-actor context, pass the provider
> **type** instead. That skips the key path, and you `await` the hop:
>
> ```swift
> // The type-based init is nonisolated, so the wrapper can be declared anywhere.
> @ReconFlag(FirebaseConfigProvider.self, .isCheckoutV2Enabled)
> private var isV2Enabled: Bool
>
> let isV2Enabled: Bool = await Recon.value(
>     FirebaseConfigProvider.self,
>     .isCheckoutV2Enabled
> )
> ```

The typed accessors — ``stringValue``, ``intValue``, ``doubleValue``,
``boolValue``, ``dateValue``, ``jsonValue``, and ``decodedValue(_:)`` — log a
warning when the type you read with doesn't match the key's declared
``expectedType``. A `.string` key misused as `.int` shows up in your logs rather
than failing quietly.

JSON-backed keys can decode straight into a model. Make the model `Decodable`
and opt in:

```swift
// TODO: example — the original text ended here.
```

```swift
struct FeatureFlags: Decodable, ConfigDecodable {}

let flags = Recon.shared.decodedValue(\.firebase, .featureFlagsJson, FeatureFlags.self)
```

---

## Code generation (recon-keygen)

Rather than hand-writing key enums, drop a plist named `<EnumName>.rcf.plist` anywhere in a target that has `ReconKeygenPlugin` attached. Its keys and default values become the source of truth, and the plugin regenerates a `<EnumName>Key` enum on every build.

**`Firebase.rcf.plist`:**

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

This generates a `FirebaseKey` enum equivalent to the hand-written one above. `snake_case` entries become `camelCase` cases, and `expectedType` is inferred from the value's native plist type — string, integer, real, boolean, date, or a `{…}`/`[…]` string that itself parses as JSON.

Flags can also carry an expiry, which surfaces as an Xcode build warning once passed:

```xml
<key>oldMigrationFlag</key>
<dict>
    <key>value</key><false/>
    <key>expires</key><date>2026-01-01T00:00:00Z</date>
</dict>
```

---

## Local overrides and the debug UI

An override wins over whatever the provider would otherwise serve, and persists in `UserDefaults` until removed — `source(for:)` reports `.override` while one is active. Overrides power the debug UI, but they're just as usable from code: UI tests, launch arguments, a custom debug menu.

### Setting overrides in code

```swift
// Set, read, and remove an override by key path.
Recon.shared.addOverride(\.firebase, .isCheckoutV2Enabled, true)
Recon.shared.overrideValue(\.firebase, .isCheckoutV2Enabled)   // -> ReconConfigValue?
Recon.shared.removeOverride(\.firebase, .isCheckoutV2Enabled)

// Clear every override for a provider.
Recon.shared.clearOverrides(\.firebase)
```

Each of these has a `provider:`-based twin — `addOverride(provider:key:value:)`, `removeOverride(provider:key:)` — for when you hold the provider instance rather than a key path.

Two behaviours worth knowing:

- Setting an override whose value is `nil` removes it instead.
- Setting one whose value doesn't parse as the key's `expectedType` logs a warning but still applies. This is deliberate, so QA can push a "bad" value to exercise error handling.

### The debug screen

`ReconConfigListView` is a ready-made SwiftUI screen listing every key across all registered providers, with a segmented picker to switch providers and a search field to filter keys. Overridden keys float to the top. Drop it behind a debug menu:

```swift
NavigationStack {
    ReconConfigListView()
}
```

- Tap a row's value field and press the orange button to set an override.
- Swipe a currently-overridden row to remove it.
- Pull to refresh re-fetches the selected provider.
- Each row shows a badge for where its value comes from: `REMOTE`, `LOCAL`, or `OVERRIDDEN`.

Pass `authorised: false` to render the screen read-only — useful for builds where only some users should be able to change flags:

```swift
ReconConfigListView(authorised: isDebugMenuUnlocked)
```

The view operates on `Recon.shared` by default; pass a different instance with `ReconConfigListView(recon:)` if you need to.

### Exporting and importing overrides

The full set of active overrides serializes to a single string and restores later — handy for sharing a repro from a tester's device, seeding overrides in a UI test, or carrying a flag combination between installs.

```swift
// Serialize every active override to one line.
let export = Recon.shared.getOverrides()

// Restore them on another device or launch.
// Throws OverridesParseError if the payload is malformed.
try Recon.shared.setOverrides(from: export)
```

The format joins overrides with `&`, each a percent-encoded `provider|key|value` triple, so ordinary flag names and values stay human-readable and only characters that would collide with the delimiters get escaped. `setOverrides(from:)` tolerates a payload that was percent-encoded a second time in transit — say, passed through a URL or web form — and decodes it once before parsing.

> [!NOTE]
> Restoring **replaces** the entire override set, so it's a faithful snapshot rather than a merge.

---

## Validating config at startup

A provider's raw value is just a string, so a backend can serve something that doesn't parse as a key's `expectedType`. (`"3"` is fine when `maxRetryCount` expects `.int`; `"abc"` isn't.) Validate a single key or every key for a provider, and handle the aggregated `ConfigTypeMismatchError`:

```swift
do {
    try Recon.shared.firebase.validateAll()              // every key
    try Recon.shared.firebase.validate(.maxRetryCount)   // or just one
} catch let error as ConfigTypeMismatchError {
    // error.mismatches: [(key, expected type, raw value)]
    Log.error(error.description, .named("Startup"))
}
```

Calling `validateAll()` once after your provider's first `refresh()` — right after `addRemoteConfigProvider` — catches a misconfigured backend value before any call site trips over it.

---

## Testing

Run the package's tests with:

```sh
swift test
```

`ReconTests` is the place to add coverage as you build out custom providers and keys. It ships as an empty starting point.

---

## Project layout

```
Sources/
  Recon/
    Enums/                 ReconConfigSource, ReconConfigValueType
    Errors/                ConfigTypeMismatchError, OverridesParseError
    Extensions/            ConfigDecodable, Recon+Accessors, Recon+Overrides
    Property Wrappers/     ReconFlag
    Protocols/             ReconConfigKey, ReconRemoteConfigProvider
    Structs/               ReconConfigValue
    Views/                 ReconConfigListView (debug UI)
    Recon.swift            The Recon.shared singleton
  recon-keygen/
    main.swift             The plist -> Swift enum code-gen CLI
Plugins/
  ReconKeygenPlugin/
    Plugin.swift           SPM build tool plugin, runs recon-keygen on every *.rcf.plist
Tests/
  ReconTests/
```

---

Thank you for using Recon!

*iOS Team, The Guardian*
