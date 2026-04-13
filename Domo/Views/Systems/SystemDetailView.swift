import SwiftUI

struct SystemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddTask = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteTask: MaintenanceTask?
    @State private var selectedTask: MaintenanceTask?
    var system: HomeSystem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                facts
                tasksSection
                notesSection
                docsAndAI
                deleteSection
            }
            .padding(20)
        }
        .navigationTitle(system.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete System", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheetView(
                isPresented: $showingAddTask,
                preselectedSystemID: system.id,
                lockSystemSelection: true
            )
            .environmentObject(store)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(task: task)
                .environmentObject(store)
        }
        .alert(
            "Delete System?",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    store.deleteSystem(system)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Delete \(system.name)? This also removes its linked tasks.")
            }
        )
        .alert(
            "Delete Task?",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteTask = nil }
                }
            ),
            actions: {
                Button("Delete", role: .destructive) {
                    guard let task = pendingDeleteTask else { return }
                    store.deleteTask(task)
                    pendingDeleteTask = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteTask = nil
                }
            },
            message: {
                if let task = pendingDeleteTask {
                    Text("Delete \(task.title)?")
                }
            }
        )
    }

    private var header: some View {
        SurfaceCard {
            HStack(spacing: 16) {
                Image(systemName: system.photoSymbol)
                    .font(.system(size: 34, weight: .regular))
                    .frame(width: 74, height: 74)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(system.name)
                        .font(.title2.weight(.semibold))
                    Text(system.brandModel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(system.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }

                Spacer()

                let health = store.healthSnapshot(for: system)
                ScoreRingView(score: health.score, band: health.band, size: 82)
            }
        }
    }

    private var facts: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                KeyValueRow(label: "Install Date", value: system.installDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                KeyValueRow(label: "Age", value: ageText)
                KeyValueRow(label: "Last Service", value: system.lastServiceDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not yet logged")
                KeyValueRow(label: "Next Maintenance", value: store.nextMaintenanceDate(for: system)?.formatted(date: .abbreviated, time: .omitted) ?? "No upcoming tasks")
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "Recurring Maintenance")
                Spacer()
                Button {
                    showingAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            SurfaceCard {
                let systemTasks = store.tasks(for: system)
                if systemTasks.isEmpty {
                    Text("No tasks yet. Add recurring care to improve score confidence.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(systemTasks) { task in
                        TaskRowView(task: task, systemName: nil, isPendingCompletion: store.isPendingCompletion(task)) {
                            store.toggleTaskCompletion(task)
                        } onSelect: {
                            selectedTask = task
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteTask = task
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Notes")
            SurfaceCard {
                Text(system.notes.isEmpty ? "No notes yet." : system.notes)
                    .font(.body)
                    .foregroundStyle(system.notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var docsAndAI: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Documents & AI")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(system.documentPlaceholder, systemImage: "doc.text")
                        .font(.subheadline)
                    Text("Use AI Setup to refine maintenance intervals based on model details and photo evidence.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Open AI Recommendations") {}
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var deleteSection: some View {
        SurfaceCard {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete System")
                    Spacer()
                }
                .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }

    private var ageText: String {
        guard let installDate = system.installDate,
              let years = Calendar.current.dateComponents([.year], from: installDate, to: .now).year else {
            return "Unknown"
        }
        return "\(years) years"
    }
}

#Preview {
    NavigationStack {
        SystemDetailView(system: SampleDataFactory.seed().systems[0])
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
