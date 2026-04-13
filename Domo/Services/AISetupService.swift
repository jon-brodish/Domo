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
    case invalidURL
    case invalidResponse
}

struct OpenAISetupService: AISetupService {
    func analyze(input: AISetupInput) async throws -> AISetupSuggestion {
        // Wire a real OpenAI API call here (Responses API or Chat Completions + vision).
        // Build a prompt from image + userHint, then parse structured JSON response.
        // Store API key in Keychain or secure backend token exchange, never in source.
        throw AISetupError.unavailable
    }
}

struct BackendProxyAISetupService: AISetupService {
    let endpoint: URL
    var session: URLSession = .shared

    func analyze(input: AISetupInput) async throws -> AISetupSuggestion {
        struct RequestBody: Encodable {
            let userHint: String
            let imageBase64: String?
        }

        struct ResponseEnvelope: Decodable {
            let suggestion: SuggestionDTO
        }

        struct SuggestionDTO: Decodable {
            let suggestedName: String
            let category: HomeSystemCategory
            let brandModel: String
            let confidence: Double
            let photoSymbol: String
            let notes: String
            let tasks: [TaskDTO]
        }

        struct TaskDTO: Decodable {
            let title: String
            let notes: String
            let recurrenceDays: Int
            let priority: TaskPriority
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                userHint: input.userHint,
                imageBase64: input.imageData?.base64EncodedString()
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AISetupError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AISetupError.unavailable
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let dto = decoded.suggestion

        return AISetupSuggestion(
            suggestedName: dto.suggestedName,
            category: dto.category,
            brandModel: dto.brandModel,
            confidence: dto.confidence,
            photoSymbol: dto.photoSymbol.isEmpty ? dto.category.symbol : dto.photoSymbol,
            notes: dto.notes,
            tasks: dto.tasks.map { item in
                AIRecommendedTask(
                    title: item.title,
                    notes: item.notes,
                    recurrence: .every(days: max(1, item.recurrenceDays)),
                    priority: item.priority
                )
            }
        )
    }
}
