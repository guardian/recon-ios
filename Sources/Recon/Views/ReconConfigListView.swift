import SwiftUI

public struct ReconConfigListView: View {
    
    let recon: Recon
    
    @State var selectedProvider: String
    @State var searchText: String = ""

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
                RemoteConfigListRow(key: key, provider: provider)
                    .swipeActions {
                        Button {
                            provider?.setOverride(for: key, value: .init("overrideee"), in: recon)
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
    @State private var value: String = "?"
    @State private var source: ReconConfigSource = .local
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var readyToOverride: Bool = false
    @State private var cancelOverride: Bool = false
    @State private var doOverride: Bool = false
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack(spacing: 5) {
                    Text(".\(caseName(for: key.rawKey))")
                        .font(.system(size: 15))
                        .bold()
                    Spacer()
                    sourceTag(source: source)
                    if cancelOverride {
                        Button {
                            provider?.removeOverride(for: key, in: .shared)
                            refresh()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .scaleEffect(x: 1.2, y: 1.2)
                        }
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
                    if doOverride {
                        Button {
                            provider?.setOverride(for: key, value: .init(value), in: .shared)
                            refresh()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .scaleEffect(x: 1.2, y: 1.2)
                        }
                    }
                }
            }
        }
        .onChange(of: text, { oldValue, newValue in
            guard isFocused else { return }
            withAnimation {
                doOverride = true
            }
        })
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
    }

    @ViewBuilder
    func sourceTag(source: ReconConfigSource) -> some View {
        Text(source == .remote ? "REMOTE" : (source == .override ? "OVERRIDE" : "LOCAL"))
            .font(.caption2)
            .bold()
            .foregroundStyle(source == .remote ? Color.green : (source == .override ? Color.red : Color.blue))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background {
                Capsule().stroke(source == .remote ? Color.green : (source == .override ? Color.red : Color.blue))
            }
    }
    
    func caseName(for key: String) -> String {
        let parts = key.split(separator: "_")
        guard let first = parts.first else { return "" }
        return parts.dropFirst().reduce(String(first)) { $0 + $1.prefix(1).uppercased() + $1.dropFirst() }
    }
}

#Preview {
    NavigationStack {
        ReconConfigListView()
    }
}
