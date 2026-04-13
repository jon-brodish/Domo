import SwiftUI

struct SystemsListView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var showingAdd = false
    @State private var query = ""

    var filteredSystems: [HomeSystem] {
        guard !query.isEmpty else { return store.systems }
        return store.systems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.brandModel.localizedCaseInsensitiveContains(query) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSystems) { system in
                    NavigationLink {
                        SystemDetailView(system: system)
                    } label: {
                        SystemTileView(system: system, health: store.healthSnapshot(for: system), nextDate: store.nextMaintenanceDate(for: system))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle("Systems")
        .searchable(text: $query, prompt: "Find a system or appliance")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add System", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSystemFlowView(isPresented: $showingAdd)
                .environmentObject(store)
        }
    }
}

#Preview {
    NavigationStack {
        SystemsListView()
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
