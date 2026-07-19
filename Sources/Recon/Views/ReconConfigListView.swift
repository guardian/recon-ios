import SwiftUI

public struct ReconConfigListView: View {
    
    let recon: Recon
    
    @State var selectedProvider: String

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
            Picker("Subsystem", selection: $selectedProvider) {
                ForEach(Array(Set(recon.remoteConfigProviders.map { $0.title })).sorted(), id: \.self) { title in
                    Text(title).tag(title)
                }
            }
            .pickerStyle(.segmented)
            .tint(.primary)
            .padding()
            let keys: [any ReconConfigKey] = provider?.allKeys ?? []

            List(keys, id: \.rawKey) { key in
                RemoteConfigListRow(key: key, provider: provider)
                .padding(.vertical, 2)
            }
        }
        .ignoresSafeArea(edges: [.bottom])
        .navigationTitle("Remote Config")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RemoteConfigListRow: View {
    
    let key: any ReconConfigKey
    let provider: (any ReconRemoteConfigProvider)?
    @State private var value: String = "?"

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text(".\(caseName(for: key.rawKey))")
                        .font(.system(size: 15))
                        .bold()
                    sourceTag(source: .override)
                    Spacer()
                }
                Divider()
                HStack {
                    Text(value)
                        .monospaced()
                        .foregroundStyle(.gray)
                    Spacer()
                    if value == "true" || value == "false" {
                        Toggle("", isOn: .constant(value == "true" ? true : false))
                            .disabled(true)
                            .tint(.green)
                    }
                }
            }
        }
        .onAppear {
            self.value = provider?.anyValue(for: key)?.stringValue ?? "?"
        }
    }
    
    @ViewBuilder
    func sourceTag(source: ReconConfigSource) -> some View {
        Text(source == .remote ? "REMOTE" : (source == .override ? "OVERRIDE" : "LOCAL"))
            .font(.caption2)
            .bold()
            .foregroundStyle(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background {
                Capsule().fill(source == .remote ? Color.green : (source == .override ? Color.red : Color.blue))
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
