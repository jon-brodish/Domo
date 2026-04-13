import SwiftUI

struct SystemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddTask = false
    @State private var showingEditSystem = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteTask: MaintenanceTask?
    @State private var selectedTask: MaintenanceTask?
    var system: HomeSystem
    private var displaySystem: HomeSystem {
        store.systems.first(where: { $0.id == system.id }) ?? system
    }

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
        .navigationTitle(displaySystem.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSystem = true
                } label: {
                    Label("Edit System", systemImage: "pencil")
                }
            }
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
                preselectedSystemID: displaySystem.id,
                lockSystemSelection: true
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showingEditSystem) {
            SystemEditorSheetView(isPresented: $showingEditSystem, system: displaySystem)
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
                    store.deleteSystem(displaySystem)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Delete \(displaySystem.name)? This also removes its linked tasks.")
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
                Image(systemName: displaySystem.photoSymbol)
                    .font(.system(size: 34, weight: .regular))
                    .frame(width: 74, height: 74)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(displaySystem.name)
                        .font(.title2.weight(.semibold))
                    Text(displaySystem.brandModel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(displaySystem.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }

                Spacer()

                let health = store.healthSnapshot(for: displaySystem)
                ScoreRingView(score: health.score, band: health.band, size: 82)
            }
        }
    }

    private var facts: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                KeyValueRow(label: "Install Date", value: displaySystem.installDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                KeyValueRow(label: "Age", value: ageText)
                KeyValueRow(label: "Last Service", value: displaySystem.lastServiceDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not yet logged")
                KeyValueRow(label: "Next Maintenance", value: store.nextMaintenanceDate(for: displaySystem)?.formatted(date: .abbreviated, time: .omitted) ?? "No upcoming tasks")
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
                let systemTasks = store.tasks(for: displaySystem)
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
                Text(displaySystem.notes.isEmpty ? "No notes yet." : displaySystem.notes)
                    .font(.body)
                    .foregroundStyle(displaySystem.notes.isEmpty ? .secondary : .primary)
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
        guard let installDate = displaySystem.installDate,
              let years = Calendar.current.dateComponents([.year], from: installDate, to: .now).year else {
            return "Unknown"
        }
        return "\(years) years"
    }
}

private struct SystemEditorSheetView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool
    let system: HomeSystem

    @State private var name: String
    @State private var brandModel: String
    @State private var category: HomeSystemCategory
    @State private var installDate: Date
    @State private var hasInstallDate: Bool
    @State private var lastServiceDate: Date
    @State private var hasLastServiceDate: Bool
    @State private var notes: String

    init(isPresented: Binding<Bool>, system: HomeSystem) {
        _isPresented = isPresented
        self.system = system
        _name = State(initialValue: system.name)
        _brandModel = State(initialValue: system.brandModel)
        _category = State(initialValue: system.category)
        _installDate = State(initialValue: system.installDate ?? .now)
        _hasInstallDate = State(initialValue: system.installDate != nil)
        _lastServiceDate = State(initialValue: system.lastServiceDate ?? .now)
        _hasLastServiceDate = State(initialValue: system.lastServiceDate != nil)
        _notes = State(initialValue: system.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("System") {
                    TextField("Name", text: $name)
                    TextField("Brand / Model", text: $brandModel)
                    Picker("Category", selection: $category) {
                        ForEach(HomeSystemCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Dates") {
                    Toggle("Known install date", isOn: $hasInstallDate)
                    if hasInstallDate {
                        DatePicker("Install Date", selection: $installDate, displayedComponents: .date)
                    }

                    Toggle("Last service logged", isOn: $hasLastServiceDate)
                    if hasLastServiceDate {
                        DatePicker("Last Service", selection: $lastServiceDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit System")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateSystem(
                            system.id,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            brandModel: brandModel.trimmingCharacters(in: .whitespacesAndNewlines),
                            installDate: hasInstallDate ? installDate : nil,
                            lastServiceDate: hasLastServiceDate ? lastServiceDate : nil,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SystemDetailView(system: SampleDataFactory.seed().systems[0])
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
