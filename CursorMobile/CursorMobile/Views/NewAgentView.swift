import SwiftUI

struct NewAgentView: View {
    var onCreated: (() -> Void)?

    @StateObject private var viewModel = NewAgentViewModel()
    @State private var navigateToAgent = false
    @State private var createdAgentId: String?
    @State private var createdAgentName: String?
    @State private var createdPrompt: String?

    var body: some View {
        NavigationStack {
            Form {
                promptSection
                repositorySection
                optionsSection

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Agent")
            .navigationDestination(isPresented: $navigateToAgent) {
                if let id = createdAgentId, let name = createdAgentName {
                    AgentDetailView(
                        agentId: id,
                        agentName: name,
                        initialPrompt: createdPrompt
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                createButton
            }
            .task {
                await viewModel.loadMetadata()
            }
        }
    }

    private var promptSection: some View {
        Section {
            TextField("What should the agent do?", text: $viewModel.prompt, axis: .vertical)
                .lineLimit(3...8)
        } header: {
            Text("Task")
        } footer: {
            Text("Describe the coding task. The agent will work in a cloud VM on your repository.")
        }
    }

    private var repositorySection: some View {
        Section("Repository") {
            if viewModel.isLoadingRepos {
                HStack {
                    ProgressView()
                    Text("Loading repositories…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.repositories.isEmpty {
                Text("No repositories found. Connect GitHub in Cursor settings.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                Picker("Repository", selection: $viewModel.selectedRepo) {
                    ForEach(viewModel.repositories) { repo in
                        Text(repo.displayName).tag(Optional(repo))
                    }
                }

                TextField("Branch", text: $viewModel.branch)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if !viewModel.models.isEmpty {
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.models) { model in
                        Text(model.displayName).tag(Optional(model))
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Picker("Mode", selection: $viewModel.mode) {
                ForEach(NewAgentViewModel.AgentMode.allCases) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.title)
                        Text(mode.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.navigationLink)

            Toggle("Auto-create Pull Request", isOn: $viewModel.autoCreatePR)
        }
    }

    private var createButton: some View {
        Button {
            Task { await createAgent() }
        } label: {
            HStack {
                if viewModel.isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                    Text("Start Agent")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(CursorTheme.accent)
        .disabled(viewModel.isCreating || viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func createAgent() async {
        let success = await viewModel.createAgent()
        if success, let agent = viewModel.createdAgent {
            createdAgentId = agent.id
            createdAgentName = agent.name
            createdPrompt = viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.reset()
            onCreated?()
            navigateToAgent = true
        }
    }
}
