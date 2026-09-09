# AI Code Learning and Preview Standard

This repository is used with multiple AI coding assistants. The human-readable goal is: **read the code, explain it clearly, make changes safely, and always provide a result the user can preview or verify.**

## Required workflow

1. **Read before changing**
   - Inspect the README, directory tree, dependency files, entry points, tests, and existing AI instruction files.
   - Explain in plain Traditional Chinese what the repository does, how it starts, and how its main parts connect.
   - State uncertainties instead of guessing.

2. **Teach while working**
   - For important code, explain: input → processing → output.
   - Introduce technical terms with a short plain-language definition.
   - Show the relevant file path and why that file matters.
   - Use a compact diagram or table when relationships are easier to understand visually.

3. **Plan safe changes**
   - Identify the exact files and expected behavior before editing.
   - Preserve unrelated user changes and existing project conventions.
   - Never expose secrets, tokens, personal data, or local configuration.
   - Do not publish, deploy, merge, or perform destructive actions without explicit authorization.

4. **Verify**
   - Run the smallest relevant tests, type checks, lint checks, and build commands.
   - Report the commands used and the actual results.
   - If verification cannot run, explain the blocker and provide a reproducible manual check.

5. **Provide a preview**
   Use the most direct format available:
   - Web/UI: runnable browser preview or screenshots.
   - Python/data: notebook output, tables, and charts.
   - Images/video/3D: rendered media or an interactive browser demo.
   - API/backend: example requests and responses plus a test page when practical.
   - Algorithms/CLI: sample input, intermediate behavior, and output.
   - Documentation: rendered Markdown or generated document preview.

## Response format

For substantial work, finish with:

- **這是什麼** — purpose in plain language.
- **如何運作** — important files and execution flow.
- **改了什麼** — exact files and behavioral changes.
- **驗證結果** — tests/build results, including failures.
- **預覽方式** — a link, command, screenshot, or runnable artifact.
- **下一步** — one to three realistic learning or improvement steps.

## Language and accessibility

- Default explanations to Traditional Chinese unless the user requests another language.
- Assume the user is learning: be direct, concrete, and avoid unexplained jargon.
- Code may remain in its conventional language, but comments and teaching notes should be understandable.
