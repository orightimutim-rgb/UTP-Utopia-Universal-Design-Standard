import SwiftUI

struct AgentDetailView: View {
    let agentId: String
    let agentName: String

    @StateObject private var viewModel: AgentDetailViewModel
    @State private var showInfo = false

    init(agentId: String, agentName: String, initialPrompt: String? = nil) {
        self.agentId = agentId
        self.agentName = agentName
        _viewModel = StateObject(wrappedValue: AgentDetailViewModel(
            agentId: agentId,
            initialPrompt: initialPrompt
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let status = viewModel.currentRunStatus {
                RunStatusBar(status: status, isStreaming: viewModel.isStreaming)
            }

            ChatView(
                messages: viewModel.messages,
                isStreaming: viewModel.isStreaming
            )

            ChatInputBar(
                text: $viewModel.inputText,
                isSending: viewModel.isSending,
                isStreaming: viewModel.isStreaming,
                onSend: {
                    Task { await viewModel.sendMessage() }
                },
                onCancel: {
                    Task { await viewModel.cancelCurrentRun() }
                }
            )
        }
        .background(CursorTheme.surface)
        .navigationTitle(agentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            AgentInfoSheet(
                agent: viewModel.agent,
                runs: viewModel.runs,
                usage: viewModel.usage
            )
        }
        .overlay {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading agent…")
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

struct RunStatusBar: View {
    let status: RunStatus
    let isStreaming: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(CursorTheme.statusColor(for: status))
                .frame(width: 8, height: 8)

            Text(isStreaming ? "Agent is working…" : status.displayName)
                .font(.caption.weight(.medium))

            Spacer()

            if isStreaming {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
    }
}

struct AgentInfoSheet: View {
    let agent: Agent?
    let runs: [AgentRun]
    let usage: AgentUsageResponse?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let agent {
                    Section("Agent") {
                        LabeledContent("Name", value: agent.name)
                        LabeledContent("Status", value: agent.status.rawValue)
                        LabeledContent("Repository", value: agent.repoDisplayName)
                        LabeledContent("Branch", value: agent.branchDisplayName)

                        if let url = agent.url, let link = URL(string: url) {
                            Link("Open in Cursor", destination: link)
                        }
                    }

                    if let branches = agent.repos?.first {
                        Section("Repository") {
                            Text(branches.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Runs (\(runs.count))") {
                    ForEach(runs.prefix(10)) { run in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.id)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                Text(run.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(
                                status: run.status.displayName,
                                color: CursorTheme.statusColor(for: run.status)
                            )
                        }
                    }
                }

                if let usage {
                    Section("Token Usage") {
                        LabeledContent("Total", value: formatTokens(usage.totalUsage.totalTokens))
                        LabeledContent("Input", value: formatTokens(usage.totalUsage.inputTokens))
                        LabeledContent("Output", value: formatTokens(usage.totalUsage.outputTokens))
                    }
                }

                if let git = runs.first?.git {
                    Section("Branches") {
                        ForEach(git.branches) { branch in
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = branch.branch {
                                    Text(name)
                                        .font(.subheadline.weight(.medium))
                                }
                                Text(branch.repoUrl)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let prUrl = branch.prUrl, let link = URL(string: prUrl) {
                                    Link("View Pull Request", destination: link)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agent Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}
