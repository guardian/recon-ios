import SwiftUI

public struct ReconConfigListView: View {
    
    let recon: Recon
    
    @State var selectedProvider: String
    @State var searchText: String = ""
    @State private var overridesVersion: Int = 0

    var provider: ReconRemoteConfigProvider? {
        recon.remoteConfigProviders.first(where: { $0.title == selectedProvider })
    }
    
    public init(recon: Recon = .shared) {
        self.recon = recon
        if let firstProvider = recon.remoteConfigProviders.first {
            self.selectedProvider = firstProvider.title
        } else {
            self.selectedProvider = ""
        }
    }
    
    public var body: some View {
        VStack {
            let keys: [any ReconConfigKey] = searchText.isEmpty ? (provider?.allKeys ?? []) : (provider?.allKeys.filter({ $0.rawKey.contains(searchText) }) ?? [])

            List(keys, id: \.rawKey) { key in
                RemoteConfigListRow(key: key, provider: provider, refreshTrigger: overridesVersion)
                    .swipeActions {
                        Button {
                            provider?.setOverride(for: key, value: .init("overrideee"), in: recon)
                            overridesVersion += 1
                        } label: {
                            Image(systemName: "plus.square.fill")
                        }
                        .tint(.red)
                    }
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 65)
                    .background(.ultraThinMaterial)
                    .padding(.top, -10)
                Picker("Subsystem", selection: $selectedProvider) {
                    ForEach(Array(Set(recon.remoteConfigProviders.map { $0.title })).sorted(), id: \.self) { title in
                        Text(title).tag(title)
                    }
                }
                .background(.ultraThinMaterial)
                .clipped()
                .pickerStyle(.segmented)
                .padding([.horizontal])
            }
        }
        .searchable(text: $searchText, placement: .automatic)
        .textInputAutocapitalization(.never)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Remote Config").bold()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { oldValue, newValue in
            let keys: [any ReconConfigKey] = searchText.isEmpty ? (provider?.allKeys ?? []) : (provider?.allKeys.filter({ $0.rawKey.contains(searchText) }) ?? [])
            print(keys)
        }
    }
}

struct RemoteConfigListRow: View {
    
    let key: any ReconConfigKey
    let provider: (any ReconRemoteConfigProvider)?
    /// Bumped by the parent when it changes an override, so the row re-reads the store.
    let refreshTrigger: Int
    @State private var value: String = "?"
    @State private var source: ReconConfigSource = .local
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var readyToOverride: Bool = false
    @State private var cancelOverride: Bool = false
    @State private var doOverride: Bool = true
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(.red)
                    .frame(height: source == .override ? 35 : 0)
                    .overlay {
                        HStack {
                            Spacer()
                            if cancelOverride {
                                Button {
                                    provider?.removeOverride(for: key, in: .shared)
                                    refresh()
                                } label: {
                                    sourceTag(source: .override)
                                }
                                .padding(.trailing)
                            }
                        }
                    }
                    
                HStack(spacing: 5) {
                    Text(".\(caseName(for: key.rawKey))")
                        .font(.system(size: 15))
                        .bold()
                    Spacer()
                    if source != .override {
                        sourceTag(source: source)
                    }
                }
                .padding(.top, source == .override ? 0 : 5)
                .padding(.horizontal, 15)
                Divider()
                HStack {
                    TextField("", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .monospaced()
                        .foregroundStyle(.gray)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .onChange(of: text) { _, newValue in
                            if newValue.contains("\n") {
                                text = newValue.replacingOccurrences(of: "\n", with: "")
                                isFocused = false
                            }
                        }
//                    if doOverride {
                        Button {
                            provider?.setOverride(for: key, value: .init(text), in: .shared)
                            isFocused = false
                            refresh()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .scaleEffect(x: 1.2, y: 1.2)
                        }
                        .disabled(doOverride == false)
                        .opacity(doOverride ? 1 : 0)
//                    }
                }
                .padding([.horizontal, .bottom], 15)

            }
            .listRowInsets(EdgeInsets())
        }
        .onChange(of: text, { oldValue, newValue in
            guard isFocused else { return }
            doOverride = true
        })
        .onChange(of: refreshTrigger) { _, _ in
            refresh()
        }
        .onAppear {
            refresh()
        }
    }

    func refresh() {
        self.value = provider?.anyValue(for: key)?.stringValue ?? "?"
        self.source = provider?.anySource(for: key) ?? .local
        self.text = value
        self.readyToOverride = true
        self.cancelOverride = source == .override
        self.doOverride = false
    }

    @ViewBuilder
    func sourceTag(source: ReconConfigSource) -> some View {
        Text(source == .remote ? "REMOTE" : (source == .override ? "REMOVE OVERRIDE" : "LOCAL"))
            .font(.caption2)
            .bold()
            .foregroundStyle(source == .remote ? Color.green : (source == .override ? Color.red : Color.blue))
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background {
                if source == .override {
                    Capsule()
                        .fill(.background)
                } else {
                    Capsule().stroke(source == .remote ? Color.green : (source == .override ? Color.white : Color.blue))
                }
            }
    }
    
    func caseName(for key: String) -> String {
        let parts = key.split(separator: "_")
        guard let first = parts.first else { return "" }
        return parts.dropFirst().reduce(String(first)) { $0 + $1.prefix(1).uppercased() + $1.dropFirst() }
    }
}

fileprivate struct PreviewConfigProvider: ReconRemoteConfigProvider {

    enum Key: String, CaseIterable, ReconConfigKey {
        case remote_key
        case local_key
        case override_key

        var defaultValue: ReconConfigValue { "Hello, world!" }
        var expectedType: ReconConfigValueType { .string }
    }

    let title = "Preview"

    func refresh() async {}

    func providerValue(for key: Key) -> ReconConfigValue {
        key.defaultValue
    }

    func providerSource(for key: Key) -> ReconConfigSource {
        switch key {
        case .local_key: return .local
        case .remote_key: return .remote
        case .override_key: return .override
        }
    }
}

#Preview {
    if Recon.shared.provider(PreviewConfigProvider.self) == nil {
        Recon.shared.addRemoteConfigProvider(PreviewConfigProvider())
    }
    return NavigationStack {
        ReconConfigListView()
    }
}
