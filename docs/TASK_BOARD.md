# 任務板（GitHub Issues 關閉時的暫代）

> 用途：讓 ChatGPT / Codex / Cursor / 人類共用同一份待辦。  
> 完整同步協定見 [`GITHUB_GPT_SYNC.md`](GITHUB_GPT_SYNC.md)。  
> Issues 開啟後，優先把項目改成 GitHub Issue，並在此留下連結。

## Now（進行中）

| ID | 標題 | 負責人 | 連結 | 備註 |
|----|------|--------|------|------|
| T-001 | GitHub ↔ ChatGPT 同步安排 | Cursor Agent | 本 PR | 文件／範本／任務板 |
| T-002 | Cloud Agent 串流穩定度（mobile） | — | [#2](https://github.com/orightimutim-rgb/UTP-Utopia-Universal-Design-Standard/pull/2) | Draft PR，待審 |

## Next（下一步，建議順序）

| ID | 標題 | 建議入口 | 完成定義 |
|----|------|----------|----------|
| T-010 | 在 GitHub Settings 開啟 Issues | 網頁手動 | Issues 可開；可改用議題範本 |
| T-011 | 審閱並決定 PR #2 | ChatGPT + GitHub | Merge／要求修改／關閉 |
| T-012 | Cursor Mobile：補單元測試骨架 | Cursor Agent | 針對 ViewModel／API 客戶端有可跑測試（需 macOS CI 或本機 Xcode） |
| T-013 | 補齊 `applications/ai-assistants` 其他助理指令 | Cursor / ChatGPT | Claude／Gemini 等同風格短指令 |

## Done（已完成）

| ID | 標題 | 連結 |
|----|------|------|
| T-000 | 新增 CONTRIBUTING 根文件 | [#1](https://github.com/orightimutim-rgb/UTP-Utopia-Universal-Design-Standard/pull/1) |
| T-000b | 加入 AI_WORKFLOW／AGENTS／Claude／Copilot 指示 | main |

## 更新規則（給 AI）

1. 開始做某項 → 移到 **Now**，寫上分支或 PR 連結。  
2. 完成 → 移到 **Done**，保留 PR 連結。  
3. 一次只把 1–3 項放在 **Now**，保持手機可讀。  
4. 不要刪除歷史；Done 區可留最近 10 筆。  
