import SwiftUI

public struct ReconConfigListView: View {
    
    let recon: Recon
    
    @State var selectedProvider: String
    @State var searchText: String = ""
    @State private var overridesVersion: Int = 0
    @State private var displayedKeys: [any ReconConfigKey] = []
    
    var provider: (any ReconRemoteConfigProvider)? {
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
    
    func sortedKeys(matching searchText: String) -> [any ReconConfigKey] {
        let filtered: [any ReconConfigKey] = searchText.isEmpty ? (provider?.allKeys ?? []) : (provider?.allKeys.filter({ $0.rawKey.contains(searchText) }) ?? [])
        
        // Prefer overriden flags to appear at the top, and then sort by Alphabetical order.
        return filtered.sorted { lhs, rhs in
            let lhsOverridden = provider?.anySource(for: lhs) == .override
            let rhsOverridden = provider?.anySource(for: rhs) == .override
            if lhsOverridden != rhsOverridden {
                return lhsOverridden
            }
            return lhs.rawKey < rhs.rawKey
        }
    }

    func refreshOrder() {
        displayedKeys = sortedKeys(matching: searchText)
    }
    
    public var body: some View {
        VStack {
            List {
                Label("Tap to edit values. Swipe to remove overrides.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .listRowBackground(EmptyView())
                ForEach(displayedKeys, id: \.rawKey) { key in
                    RemoteConfigListRow(key: key, provider: provider, refreshTrigger: overridesVersion)
                        .swipeActions {
                            Button {
                                provider?.removeOverride(for: key, in: .shared)
                                overridesVersion += 1
                            } label: {
                                Label("Remove\nOverride", systemImage: "xmark")
                            }
                            .tint(.red)
                        }
                }
            }
            .listSectionSpacing(10)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 50)
                    .background(.ultraThinMaterial)
                    .padding(.top, -10)
                Picker("Provider", selection: $selectedProvider) {
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .textInputAutocapitalization(.never)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Remote Config").bold()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            refreshOrder()
        }
        .onChange(of: searchText) { _, _ in
            refreshOrder()
        }
        .onChange(of: selectedProvider) { _, _ in
            refreshOrder()
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
    @State private var cancelOverride: Bool = false
    @State private var doOverride: Bool = true
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Text(".\(caseName(for: key.rawKey))")
                        .font(.system(size: 15))
                        .bold()
                    Spacer()
                    if doOverride {
                        Button {
                            provider?.setOverride(for: key, value: .init(text), in: .shared)
                            isFocused = false
                            refresh()
                        } label: {
                            Text("OVERRIDE ?")
                                .font(.caption2)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background {
                                    Capsule()
                                        .fill(.orange)
                                }
                        }
                    } else {
                        sourceTag(source: source)
                    }
                }
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
                }
            }
        }
        .onChange(of: text, { oldValue, newValue in
            guard newValue != value else { doOverride = false; return }
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
        self.cancelOverride = source == .override
        self.doOverride = false
    }
    
    @ViewBuilder
    func sourceTag(source: ReconConfigSource) -> some View {
        Text(source == .remote ? "R" : (source == .override ? "OVERRIDDE" : "L"))
            .font(.caption2)
            .bold()
            .foregroundStyle(source == .remote ? Color.green : (source == .override ? Color.white : Color.blue))
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background {
                Capsule().fill(source == .remote ? Color.green : (source == .override ? Color.red : Color.blue))
                    .opacity(source == .override ? 1.0 : 0.15)
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
