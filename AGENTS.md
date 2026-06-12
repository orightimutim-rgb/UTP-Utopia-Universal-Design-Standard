# Codex Project Instructions

## Project identity

This repository currently contains a SwiftUI iOS client for controlling cloud coding agents from an iPhone. Do not infer the project purpose from the repository name alone. Use the source tree and this file as the source of truth.

## Primary operating model

- The user operates mainly from an iPhone 15 through ChatGPT/Codex and GitHub.
- Prefer cloud-agent and pull-request workflows over instructions that require local terminal access on the phone.
- Never assume Xcode can run on iPhone. Any build, simulator, signing, profiling, or archive step must run on a trusted macOS environment or CI runner.
- Keep tasks small, reviewable, and reversible.
- Create focused pull requests rather than large direct changes.

## Development priorities

1. Preserve one-handed mobile usability and accessibility.
2. Prefer native SwiftUI and Apple platform APIs.
3. Keep credentials in Keychain; never commit API keys, tokens, certificates, provisioning profiles, or secrets.
4. Maintain clear loading, error, offline, and empty states.
5. Avoid adding third-party dependencies unless they materially reduce complexity and are actively maintained.
6. Add or update tests for changed logic when practical.

## Required checks

Before proposing completion, run the checks available in the current environment:

- Inspect the Xcode project and Swift source structure.
- Build the relevant scheme on a macOS/Xcode runner when available.
- Run unit tests when present.
- Report commands run, failures, skipped checks, and environmental limitations.
- Do not claim an iOS build passed when no macOS/Xcode runner was available.

## Plugin guidance

Use the OpenAI `build-ios-apps` Codex plugin for SwiftUI implementation, refactoring, App Intents, performance review, and simulator debugging. Enable its XcodeBuildMCP-backed features only on a trusted macOS machine.

Do not enable unrelated plugins by default. Add Figma, Notion, Expo, Vercel, Netlify, or database plugins only when the repository actually adopts those services.

## Change policy

- Do not rewrite unrelated documentation or rename the repository without an explicit request.
- Explain any mismatch between repository documentation and implementation before making broad structural changes.
- Prefer a short plan for changes spanning multiple files.
- Preserve existing behavior unless the task explicitly requests a behavior change.
