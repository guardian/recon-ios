import SwiftUI

public struct ReconConfigListView: View {
    
    let recon: Recon
    
    @State var selectedProvider: String
    
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
            List(
                recon.remoteConfigProviders.first(where: { $0.title == selectedProvider })?.allKeys ?? [],
                id: \.rawKey
            ) { key in
                VStack(alignment: .leading) {
                    Text(key.rawKey)
                }
                .padding(.vertical, 2)
            }
        }
        .ignoresSafeArea(edges: [.bottom])
        .navigationTitle("Remote Config")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ReconConfigListView()
    }
}
