import Foundation

struct AISetupInput {
    var imageData: Data?
    var userHint: String
}

struct AIRecommendedTask: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var notes: String
    var recurrence: RecurrenceRule
    var priority: TaskPriority
}

struct AISetupSuggestion {
    var suggestedName: String
    var category: HomeSystemCategory
    var brandModel: String
    var confidence: Double
    var photoSymbol: String
    var notes: String
    var tasks: [AIRecommendedTask]
}

protocol AISetupService {
    func analyze(input: AISetupInput) async throws -> AISetupSuggestion
}

enum AISetupError: Error {
    case unavailable
    case noSuggestion
}

struct OpenAISetupService: AISetupService {
    func analyze(input: AISetupInput) async throws -> AISetupSuggestion {
        // Wire a real OpenAI API call here (Responses API or Chat Completions + vision).
        // Build a prompt from image + userHint, then parse structured JSON response.
        // Store API key in Keychain or secure backend token exchange, never in source.
        throw AISetupError.unavailable
    }
}
