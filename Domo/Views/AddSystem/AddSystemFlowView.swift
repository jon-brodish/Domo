import PhotosUI
import SwiftUI

enum AddFlowMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case ai = "AI Assist"

    var id: String { rawValue }
}

struct AddSystemFlowView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool

    @State private var mode: AddFlowMode = .manual

    @State private var name = ""
    @State private var brandModel = ""
    @State private var category: HomeSystemCategory?
    @State private var installDate = Date()
    @State private var usesInstallDate = true
    @State private var notes = ""

    @State private var aiHint = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isAnalyzing = false
    @State private var suggestion: AISetupSuggestion?
    @State private var enabledSuggestions = Set<UUID>()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Mode", selection: $mode) {
                        ForEach(AddFlowMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )

                    if mode == .manual {
                        manualForm
                    } else {
                        aiForm
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Add Home Item")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: mode)
#if os(macOS)
        .frame(minWidth: 560, minHeight: 620)
#else
        .presentationDetents([.large])
#endif
        .onChange(of: selectedItem) { _, item in
            Task { await loadPhotoData(from: item) }
        }
    }

    private var manualForm: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("System")
                inputField("Name", text: $name)
                inputField("Brand / Model", text: $brandModel)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Category")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Picker("Category", selection: $category) {
                        Text("Select category").tag(Optional<HomeSystemCategory>.none)
                        ForEach(HomeSystemCategory.allCases) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                }

                Divider()
                    .overlay(Color.primary.opacity(0.08))

                sectionLabel("Lifecycle")
                Toggle("Known install date", isOn: $usesInstallDate)
                    .toggleStyle(.switch)
                if usesInstallDate {
                    DatePicker("Install Date", selection: $installDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                }

                sectionLabel("Notes")
                TextField("Anything important to remember?", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
            }
        }
    }

    private var aiForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("AI Assist")
                    Text("Take or choose a photo, then review AI suggestions before saving.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose Appliance Photo", systemImage: "photo")
                    }

                    if selectedItem != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(photoData == nil ? "Photo selected" : "Photo ready for analysis")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if let photoData {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(photoData.count), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green.opacity(0.10))
                        )
                    }

                    TextField("Optional hint (e.g. HVAC in attic)", text: $aiHint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )

                    Button {
                        Task { await runAI() }
                    } label: {
                        if isAnalyzing {
                            ProgressView()
                        } else {
                            Label("Analyze with AI", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing)
                }
            }

            if let suggestion {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Suggestion")
                            .font(.headline)
                        Text("\(Int(suggestion.confidence * 100))% confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        KeyValueRow(label: "Name", value: suggestion.suggestedName)
                        KeyValueRow(label: "Category", value: suggestion.category.rawValue)
                        KeyValueRow(label: "Model", value: suggestion.brandModel)

                        Divider()
                        Text("Review suggested tasks before saving")
                            .font(.subheadline.weight(.medium))

                        ForEach(suggestion.tasks) { task in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { enabledSuggestions.contains(task.id) },
                                    set: { isOn in
                                        if isOn { enabledSuggestions.insert(task.id) }
                                        else { enabledSuggestions.remove(task.id) }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                        Text(task.recurrence.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func inputField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            TextField(title, text: text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private var canSave: Bool {
        switch mode {
        case .manual:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && category != nil
        case .ai:
            return suggestion != nil
        }
    }

    private func runAI() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        if photoData == nil {
            await loadPhotoData(from: selectedItem)
        }

        if let result = try? await store.runAISetup(input: AISetupInput(imageData: photoData, userHint: aiHint)) {
            suggestion = result
            enabledSuggestions = Set(result.tasks.map(\.id))
        }
    }

    private func loadPhotoData(from item: PhotosPickerItem?) async {
        guard let item else {
            photoData = nil
            return
        }

        if let data = try? await item.loadTransferable(type: Data.self) {
            photoData = data
        } else {
            photoData = nil
        }
    }

    private func save() {
        switch mode {
        case .manual:
            guard let category else { return }
            let newSystem = HomeSystem(
                name: name,
                category: category,
                brandModel: brandModel,
                installDate: usesInstallDate ? installDate : nil,
                lastServiceDate: nil,
                notes: notes,
                photoSymbol: category.symbol,
                createdFromAI: false
            )
            store.addSystem(newSystem, tasks: [])

        case .ai:
            guard let suggestion else { return }

            let system = HomeSystem(
                name: suggestion.suggestedName,
                category: suggestion.category,
                brandModel: suggestion.brandModel,
                installDate: nil,
                lastServiceDate: nil,
                notes: suggestion.notes,
                photoSymbol: suggestion.photoSymbol,
                createdFromAI: true
            )

            let selected = suggestion.tasks.filter { enabledSuggestions.contains($0.id) }
            let tasks = selected.map { item in
                MaintenanceTask(
                    title: item.title,
                    notes: item.notes,
                    dueDate: Calendar.current.date(byAdding: .day, value: item.recurrence.intervalDays, to: .now) ?? .now,
                    recurrence: item.recurrence,
                    systemID: system.id,
                    priority: item.priority,
                    origin: .suggested
                )
            }

            store.addSystem(system, tasks: tasks)
        }

        isPresented = false
    }
}

#Preview {
    AddSystemFlowView(isPresented: .constant(true))
        .environmentObject(HomeStore(aiService: MockAISetupService()))
}
