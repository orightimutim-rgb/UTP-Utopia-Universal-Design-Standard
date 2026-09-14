import Foundation

@MainActor
final class AgentDetailViewModel: ObservableObject {
    let agentId: String

    @Published var agent: Agent?
    @Published var runs: [AgentRun] = []
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var currentRun: AgentRun?
    @Published var currentRunStatus: RunStatus?
    @Published var usage: AgentUsageResponse?

    @Published var isLoading = false
    @Published var isSending = false
    @Published var isStreaming = false
    @Published var errorMessage: String?

    private let sseClient = SSEClient()
    private var streamingMessageId: String?
    private var toolCallMessageIds: [String: String] = [:]
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    init(agentId: String, initialPrompt: String? = nil) {
        self.agentId = agentId
        if let initialPrompt {
            let trimmed = initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                messages.append(ChatMessage(role: .user, text: trimmed))
            }
        }
        setupSSE()
    }

    private func setupSSE() {
        sseClient.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleStreamEvent(event)
            }
        }

        sseClient.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if case CursorAPIError.unauthorized = error {
                    isStreaming = false
                    errorMessage = error.localizedDescription
                    return
                }
                await handleStreamEnded()
            }
        }

        sseClient.onComplete = { [weak self] in
            Task { @MainActor in
                await self?.handleStreamEnded()
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let agentTask = CursorAPIService.shared.getAgent(id: agentId)
            async let runsTask = CursorAPIService.shared.listRuns(agentId: agentId)
            async let usageTask = CursorAPIService.shared.getAgentUsage(agentId: agentId)

            agent = try await agentTask
            runs = try await runsTask.items
            usage = try? await usageTask

            if let latestRunId = agent?.latestRunId,
               let run = try? await CursorAPIService.shared.getRun(agentId: agentId, runId: latestRunId) {
                currentRun = run
                currentRunStatus = run.status
                if run.status.isTerminal, let result = run.result, !result.isEmpty {
                    if messages.isEmpty {
                        appendAssistantMessage(result, isStreaming: false)
                    }
                } else if !run.status.isTerminal {
                    startStreaming(runId: latestRunId)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        isSending = true
        errorMessage = nil
        inputText = ""

        messages.append(ChatMessage(role: .user, text: text))

        do {
            let response = try await CursorAPIService.shared.createRun(
                agentId: agentId,
                prompt: text
            )
            currentRun = response.run
            currentRunStatus = response.run.status
            runs.insert(response.run, at: 0)
            startStreaming(runId: response.run.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    func cancelCurrentRun() async {
        guard let run = currentRun,
              let status = currentRunStatus,
              !status.isTerminal else { return }

        do {
            try await CursorAPIService.shared.cancelRun(agentId: agentId, runId: run.id)
            sseClient.disconnect()
            isStreaming = false
            let updated = try await CursorAPIService.shared.getRun(agentId: agentId, runId: run.id)
            currentRun = updated
            currentRunStatus = updated.status
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startStreaming(runId: String) {
        isStreaming = true
        streamingMessageId = nil
        toolCallMessageIds = [:]
        reconnectAttempts = 0
        sseClient.connect(agentId: agentId, runId: runId)
    }

    private func handleStreamEnded() async {
        guard isStreaming,
              let runId = currentRun?.id,
              let status = currentRunStatus,
              !status.isTerminal else {
            isStreaming = false
            return
        }

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            try? await Task.sleep(nanoseconds: UInt64(reconnectAttempts) * 500_000_000)
            sseClient.connect(agentId: agentId, runId: runId)
            return
        }

        isStreaming = false
        if let run = try? await CursorAPIService.shared.getRun(agentId: agentId, runId: runId) {
            currentRun = run
            currentRunStatus = run.status
            if run.status.isTerminal, let result = run.result, !result.isEmpty {
                finalizeStreamingMessage(with: result)
            }
        }
    }

    private func handleStreamEvent(_ event: StreamEvent) {
        switch event.type {
        case .status:
            if let statusStr = event.data["status"] as? String,
               let status = RunStatus(rawValue: statusStr) {
                currentRunStatus = status
            }

        case .assistant:
            if let text = event.data["text"] as? String {
                appendStreamingAssistant(text)
            }

        case .thinking:
            if let text = event.data["text"] as? String {
                messages.append(ChatMessage(role: .thinking, text: text))
            }

        case .toolCall:
            let callId = event.data["callId"] as? String ?? UUID().uuidString
            let name = event.data["name"] as? String ?? "tool"
            let status = event.data["status"] as? String ?? "running"
            let statusText = status == "completed" ? "Completed" : "Running…"

            if let messageId = toolCallMessageIds[callId],
               let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].text = statusText
                messages[index].toolStatus = status
            } else {
                let message = ChatMessage(
                    role: .toolCall,
                    text: statusText,
                    toolName: name,
                    toolStatus: status
                )
                toolCallMessageIds[callId] = message.id
                messages.append(message)
            }

        case .result:
            if let text = event.data["text"] as? String {
                finalizeStreamingMessage(with: text)
            }
            if let statusStr = event.data["status"] as? String,
               let status = RunStatus(rawValue: statusStr) {
                currentRunStatus = status
            }
            isStreaming = false
            sseClient.disconnect()
            Task { await refreshRunState() }

        case .error:
            let message = event.data["message"] as? String ?? "Stream error"
            errorMessage = message
            isStreaming = false

        case .done, .heartbeat:
            break
        }
    }

    private func refreshRunState() async {
        guard let runId = currentRun?.id else { return }
        if let run = try? await CursorAPIService.shared.getRun(agentId: agentId, runId: runId) {
            currentRun = run
            currentRunStatus = run.status
        }
        usage = try? await CursorAPIService.shared.getAgentUsage(agentId: agentId)
    }

    private func appendStreamingAssistant(_ delta: String) {
        if let id = streamingMessageId,
           let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].text += delta
        } else {
            let message = ChatMessage(role: .assistant, text: delta, isStreaming: true)
            streamingMessageId = message.id
            messages.append(message)
        }
    }

    private func finalizeStreamingMessage(with text: String) {
        if let id = streamingMessageId,
           let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].text = text
            messages[index].isStreaming = false
        } else {
            appendAssistantMessage(text, isStreaming: false)
        }
        streamingMessageId = nil
    }

    private func appendAssistantMessage(_ text: String, isStreaming: Bool) {
        messages.append(ChatMessage(role: .assistant, text: text, isStreaming: isStreaming))
    }

}
