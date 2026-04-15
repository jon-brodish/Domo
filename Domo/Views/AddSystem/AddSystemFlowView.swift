import PhotosUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum AddFlowMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case ai = "AI Assist"

    var id: String { rawValue }
}

struct AddSystemFlowView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool

    @State private var mode: AddFlowMode = .ai

    @State private var name = ""
    @State private var brandModel = ""
    @State private var category: HomeSystemCategory?
    @State private var installDate = Date()
    @State private var usesInstallDate = true
    @State private var usesWarrantyDate = false
    @State private var warrantyDate = Date()
    @State private var notes = ""

    @State private var aiHint = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isAnalyzing = false
    @State private var suggestion: AISetupSuggestion?
    @State private var enabledSuggestions = Set<UUID>()
    #if os(iOS)
    @State private var showingCamera = false
    @State private var cameraImage: UIImage?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    modeSelector

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
        #if os(iOS)
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(image: $cameraImage)
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, image in
            guard let image else { return }
            selectedItem = nil
            photoData = image.jpegData(compressionQuality: 0.9)
        }
        #endif
    }

    private var modeSelector: some View {
        HStack(spacing: 10) {
            modeOption(for: .ai)
            modeOption(for: .manual)
        }
    }

    private func modeOption(for flowMode: AddFlowMode) -> some View {
        let isSelected = mode == flowMode
        let symbol = flowMode == .ai ? "sparkles" : "square.and.pencil"
        let subtitle = flowMode == .ai ? "Scan and prefill details" : "Enter everything yourself"

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = flowMode
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                    Text(flowMode.rawValue)
                        .font(.subheadline.weight(.semibold))
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

                Toggle("Known warranty expiration", isOn: $usesWarrantyDate)
                    .toggleStyle(.switch)
                if usesWarrantyDate {
                    DatePicker("Warranty Expires", selection: $warrantyDate, displayedComponents: .date)
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
                    HStack(spacing: 8) {
                        stepPill(number: 1, title: "Photo")
                        stepPill(number: 2, title: "Review")
                        stepPill(number: 3, title: "Save")
                    }

                    Text("Scan a system photo and we’ll draft the name, model, category, and starter tasks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        #if os(iOS)
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        #endif

                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Label("Library", systemImage: "photo")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.bordered)
                    }

                    if selectedItem != nil || photoData != nil {
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
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                            } else {
                                Label("Analyze with AI", systemImage: "sparkles")
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing || (selectedItem == nil && photoData == nil))
                }
            }

            if let suggestion {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("AI Suggestion")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(suggestion.confidence * 100))% confidence")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }

                        inputField("Name", text: suggestionNameBinding)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("Category")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Picker("Category", selection: suggestionCategoryBinding) {
                                ForEach(HomeSystemCategory.allCases) { item in
                                    Text(item.rawValue).tag(item)
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

                        inputField("Model", text: suggestionModelBinding)

                        Divider()
                        Text("Review suggested tasks")
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

    private func stepPill(number: Int, title: String) -> some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.blue.opacity(0.18)))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
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

    private var suggestionNameBinding: Binding<String> {
        Binding(
            get: { suggestion?.suggestedName ?? "" },
            set: { suggestion?.suggestedName = $0 }
        )
    }

    private var suggestionModelBinding: Binding<String> {
        Binding(
            get: { suggestion?.brandModel ?? "" },
            set: { suggestion?.brandModel = $0 }
        )
    }

    private var suggestionCategoryBinding: Binding<HomeSystemCategory> {
        Binding(
            get: { suggestion?.category ?? .custom },
            set: { suggestion?.category = $0 }
        )
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
                warrantyExpirationDate: usesWarrantyDate ? warrantyDate : nil,
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

#if os(iOS)
private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let pickedImage = info[.originalImage] as? UIImage {
                parent.image = pickedImage
            }
            parent.dismiss()
        }
    }
}
#endif

#Preview {
    AddSystemFlowView(isPresented: .constant(true))
        .environmentObject(HomeStore(aiService: MockAISetupService()))
}
