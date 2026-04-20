import SwiftUI

struct SystemsListView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var showingAdd = false
    @State private var query = ""
    @State private var pendingDeleteSystem: HomeSystem?

    var filteredSystems: [HomeSystem] {
        guard !query.isEmpty else { return store.systems }
        return store.systems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.brandModel.localizedCaseInsensitiveContains(query) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filteredSystems) { system in
                NavigationLink {
                    SystemDetailView(system: system)
                } label: {
                    SystemTileView(system: system, health: store.healthSnapshot(for: system), nextDate: store.nextMaintenanceDate(for: system))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeleteSystem = system
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Systems")
        .searchable(text: $query, prompt: "Find a system or appliance")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add System", systemImage: "plus")
                }
                .buttonStyle(GlassPillButtonStyle())
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddSystemFlowView(isPresented: $showingAdd)
                .environmentObject(store)
        }
        .alert(
            "Delete System?",
            isPresented: Binding(
                get: { pendingDeleteSystem != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteSystem = nil }
                }
            ),
            actions: {
                Button("Delete", role: .destructive) {
                    guard let system = pendingDeleteSystem else { return }
                    store.deleteSystem(system)
                    pendingDeleteSystem = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteSystem = nil
                }
            },
            message: {
                if let system = pendingDeleteSystem {
                    Text("Delete \(system.name)? This also removes its linked tasks.")
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        SystemsListView()
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
