import Foundation

enum CursorAPIError: LocalizedError {
    case unauthorized
    case notFound
    case conflict(String)
    case rateLimited
    case streamExpired
    case serverError(Int)
    case decodingFailed
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key. Check your key in Cursor Dashboard → API Keys."
        case .notFound:
            return "Resource not found."
        case .conflict(let message):
            return message
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .streamExpired:
            return "Live stream expired. Fetching the latest run result…"
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .decodingFailed:
            return "Unexpected response from Cursor API."
        case .networkError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}

actor CursorAPIService {
    static let shared = CursorAPIService()

    private let baseURL = URL(string: "https://api.cursor.com")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private init() {}

    // MARK: - Auth

    func validateAPIKey() async throws -> APIKeyInfo {
        try await request(path: "/v1/me")
    }

    // MARK: - Agents

    func listAgents(limit: Int = 20, cursor: String? = nil) async throws -> AgentListResponse {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await request(path: "/v1/agents", query: query)
    }

    func getAgent(id: String) async throws -> Agent {
        try await request(path: "/v1/agents/\(id)")
    }

    func createAgent(
        prompt: String,
        repoURL: String?,
        branch: String?,
        modelId: String?,
        autoCreatePR: Bool = false,
        mode: String = "agent"
    ) async throws -> CreateAgentResponse {
        var repos: [CreateAgentRequest.RepoConfig]?
        if let repoURL {
            repos = [CreateAgentRequest.RepoConfig(url: repoURL, startingRef: branch ?? "main")]
        }

        let body = CreateAgentRequest(
            prompt: .init(text: prompt),
            model: modelId.map { CreateAgentRequest.ModelSelection(id: $0) },
            name: nil,
            repos: repos,
            autoCreatePR: autoCreatePR,
            mode: mode
        )

        return try await request(path: "/v1/agents", method: "POST", body: body)
    }

    // MARK: - Runs

    func listRuns(agentId: String, limit: Int = 20) async throws -> RunListResponse {
        let query = [URLQueryItem(name: "limit", value: "\(limit)")]
        return try await request(path: "/v1/agents/\(agentId)/runs", query: query)
    }

    func getRun(agentId: String, runId: String) async throws -> AgentRun {
        try await request(path: "/v1/agents/\(agentId)/runs/\(runId)")
    }

    func createRun(agentId: String, prompt: String, mode: String? = nil) async throws -> CreateRunResponse {
        let body = CreateRunRequest(prompt: .init(text: prompt), mode: mode)
        return try await request(path: "/v1/agents/\(agentId)/runs", method: "POST", body: body)
    }

    func cancelRun(agentId: String, runId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/v1/agents/\(agentId)/runs/\(runId)/cancel",
            method: "POST"
        )
    }

    func getAgentUsage(agentId: String) async throws -> AgentUsageResponse {
        try await request(path: "/v1/agents/\(agentId)/usage")
    }

    // MARK: - Metadata

    func listRepositories() async throws -> RepositoryListResponse {
        try await request(path: "/v1/repositories")
    }

    func listModels() async throws -> ModelListResponse {
        try await request(path: "/v1/models")
    }

    // MARK: - Networking

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw CursorAPIError.unauthorized
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }

        guard let url = components.url else {
            throw CursorAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CursorAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw CursorAPIError.unauthorized
        case 404:
            throw CursorAPIError.notFound
        case 409:
            let message = parseErrorMessage(from: data) ?? "Request conflict."
            throw CursorAPIError.conflict(message)
        case 429:
            throw CursorAPIError.rateLimited
        default:
            throw CursorAPIError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CursorAPIError.decodingFailed
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["message"] as? String ?? json["error"] as? String
    }
}

private struct EmptyResponse: Decodable {}
