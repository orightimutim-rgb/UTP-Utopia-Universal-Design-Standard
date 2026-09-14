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
    /// Prevents reconnect after the user cancels a run.
    private var isCancelling = false

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

                if self.isCancelling {
                    self.isStreaming = false
                    return
                }

                if case CursorAPIError.unauthorized = error {
                    self.isStreaming = false
                    self.errorMessage = error.localizedDescription
                    return
                }

                // 410 stream retention expired: never reconnect — fetch final run via REST.
                if case CursorAPIError.streamExpired = error {
                    await self.fetchFinalRunState()
                    return
                }

                await self.handleStreamEnded()
            }
        }

        sseClient.onComplete = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isCancelling {
                    self.isStreaming = false
                    return
                }
                await self.handleStreamEnded()
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

        isCancelling = true
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
        isCancelling = false
    }

    private func startStreaming(runId: String) {
        isCancelling = false
        isStreaming = true
        streamingMessageId = nil
        toolCallMessageIds = [:]
        reconnectAttempts = 0
        sseClient.connect(agentId: agentId, runId: runId)
    }

    private func handleStreamEnded() async {
        guard !isCancelling else {
            isStreaming = false
            return
        }

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
            guard !isCancelling, isStreaming else {
                isStreaming = false
                return
            }
            sseClient.connect(agentId: agentId, runId: runId)
            return
        }

        await fetchFinalRunState()
    }

    private func fetchFinalRunState() async {
        isStreaming = false
        guard let runId = currentRun?.id else { return }
        if let run = try? await CursorAPIService.shared.getRun(agentId: agentId, runId: runId) {
            currentRun = run
            currentRunStatus = run.status
            if run.status.isTerminal, let result = run.result, !result.isEmpty {
                finalizeStreamingMessage(with: result)
            }
        }
    }

    private func handleStreamEvent(_ event: StreamEvent) {
        // A live event after reconnect means the stream is healthy again.
        if reconnectAttempts > 0 {
            reconnectAttempts = 0
        }

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
            let name = event.data["name"] as? String ?? "tool"
            let status = event.data["status"] as? String ?? "running"
            // Prefer server callId; fall back to a stable name-based key — never a random UUID.
            let callId = (event.data["callId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key: String
            if let callId, !callId.isEmpty {
                key = callId
            } else {
                key = "name:\(name)"
            }
            let statusText = status == "completed" ? "Completed" : "Running…"

            if let messageId = toolCallMessageIds[key],
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
                toolCallMessageIds[key] = message.id
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
