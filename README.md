# Cursor Mobile for iPhone

A native SwiftUI iOS app that lets you use **Cursor Cloud Agents** from your iPhone. Chat with AI agents, launch coding tasks on GitHub repositories, stream responses in real time, and manage pull requests — all optimized for one-handed mobile use.

## Features

- **Agent Chat** — Stream assistant responses, tool calls, and thinking updates via Server-Sent Events
- **Cloud Agents** — Create agents against your GitHub repos directly from your phone
- **Repository Picker** — Browse repos connected through Cursor's GitHub integration
- **Model Selection** — Choose from available Cursor models or use the server default
- **Pull Requests** — Optionally auto-create PRs when agents finish
- **Secure Auth** — API keys stored in the iOS Keychain, never logged or transmitted except to Cursor's API
- **Dark Mode** — System, light, or dark appearance

## Requirements

- iPhone or iPad running **iOS 17+**
- **Xcode 15+** on macOS to build and run
- A **Cursor account** with a user API key ([Cursor Dashboard → API Keys](https://cursor.com/settings))
- GitHub repositories connected in Cursor settings

## Getting Started

1. Clone this repository
2. Open `CursorMobile/CursorMobile.xcodeproj` in Xcode
3. Select your development team under **Signing & Capabilities**
4. Build and run on a simulator or connected iPhone (⌘R)

### First Launch

1. Paste your Cursor API key on the onboarding screen
2. The app validates the key against `GET /v1/me`
3. Browse agents, create new ones, and chat with running agents

## Project Structure

```
CursorMobile/
├── CursorMobile.xcodeproj
└── CursorMobile/
    ├── CursorMobileApp.swift      # App entry + auth routing
    ├── Models/                    # Agent, Run, Repository types
    ├── Services/                  # API client, Keychain, SSE streaming
    ├── ViewModels/                # Observable state for each screen
    ├── Views/                     # SwiftUI screens
    └── Theme/                     # Colors and shared styles
```

## API Integration

The app talks directly to the [Cursor Cloud Agents API v1](https://cursor.com/docs/cloud-agent/api/endpoints):

| Endpoint | Usage |
|----------|-------|
| `GET /v1/me` | Validate API key |
| `GET /v1/agents` | List cloud agents |
| `POST /v1/agents` | Create a new agent |
| `POST /v1/agents/{id}/runs` | Send follow-up prompts |
| `GET /v1/agents/{id}/runs/{runId}/stream` | Stream SSE responses |
| `GET /v1/repositories` | List GitHub repos |
| `GET /v1/models` | List available models |

Authentication uses `Authorization: Bearer <api_key>`.

## Screenshots

The app includes three main tabs:

- **Agents** — List of your cloud agents with status badges and pull-to-refresh
- **New** — Form to describe a task, pick a repo/branch/model, and start an agent
- **Settings** — Account info, appearance, sign out

## GitHub ↔ ChatGPT collaboration

This repo is meant to be driven from an iPhone via ChatGPT/Codex and GitHub:

- [docs/GITHUB_GPT_SYNC.md](docs/GITHUB_GPT_SYNC.md) — GitHub ↔ ChatGPT ↔ Cursor sync
- [docs/KEEP_GPT_SYNC.md](docs/KEEP_GPT_SYNC.md) — Google Keep ↔ ChatGPT sync (manual paste; no Keep API)
- [docs/TASK_BOARD.md](docs/TASK_BOARD.md) — Now / Next / Done board (Issues currently disabled)
- [applications/ai-assistants/](applications/ai-assistants/) — paste-ready ChatGPT instructions

## Privacy

- Your API key is stored only in the device Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- No third-party analytics or backend servers
- All requests go directly to `api.cursor.com`

## License

Part of the UTP Utopia Universal Design Standard project.
