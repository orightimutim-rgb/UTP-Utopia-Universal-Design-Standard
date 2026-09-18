# GitHub ↔ ChatGPT / Codex 同步協定

本文件讓 **GitHub（程式與 PR 真相來源）**、**ChatGPT / Codex（手機端主要入口）**、**Cursor Cloud Agents（實際改碼）** 使用同一套安排，避免各說各話。

## 角色分工

| 角色 | 在哪裡 | 負責什麼 |
|------|--------|----------|
| 你（人類） | iPhone + ChatGPT / Codex | 用口語下指令、審 PR、決定合併 |
| ChatGPT / Codex | OpenAI 生態 | 釐清需求、寫任務說明、開／跟 PR 討論 |
| Cursor Cloud Agent | 本倉庫 cloud agent | 讀碼、改碼、提交、開 PR |
| GitHub | 本倉庫 | 分支、PR、範本、任務板、審查紀錄 |

## 單一真相來源

1. **程式碼** → `main` 與已合併的 PR  
2. **進行中工作** → 開啟中的 Pull Request（標題、說明、checklist）  
3. **待辦與優先順序** → [`docs/TASK_BOARD.md`](TASK_BOARD.md)（因 Issues 目前關閉，先用任務板）  
4. **AI 行為準則** → [`AGENTS.md`](../AGENTS.md) + [`AI_WORKFLOW.md`](../AI_WORKFLOW.md)  
5. **隨手靈感（Keep）** → [`KEEP_GPT_SYNC.md`](KEEP_GPT_SYNC.md)（手動貼上，非自動 API）

## 標準一回合流程（手機可用）

```text
你在 ChatGPT/Codex 描述需求
        ↓
寫進 TASK_BOARD（或直接請 Cursor agent）
        ↓
Cursor Cloud Agent 開分支 cursor/<主題>-xxxx → 改碼 → push → 開 Draft PR
        ↓
你在 GitHub / ChatGPT 審 PR
        ↓
確認後合併 → 更新 TASK_BOARD 為 Done
```

### ChatGPT 對 Cursor 的最短提示範本

把下面貼給 ChatGPT／Codex，再轉給 Cursor agent：

```text
倉庫：orightimutim-rgb/UTP-Utopia-Universal-Design-Standard
請遵循 AGENTS.md 與 AI_WORKFLOW.md。
目標：（一句話）
範圍：（要改／不要改的檔案或畫面）
完成定義：開 Draft PR、說明驗證結果與預覽方式。
限制：不要提交 secrets；不要合併；不要無關大重構。
```

### Cursor Agent 對 GitHub 的最低交付

每次任務至少交付：

1. 專用分支（`cursor/...`）  
2. 清楚 commit message  
3. Draft PR（含測試計畫與預覽說明）  
4. 若有任務板項目，把狀態改為 `In Progress` / `Done`

## GitHub 端已安排項目

| 項目 | 路徑 | 狀態 |
|------|------|------|
| PR 範本 | `.github/PULL_REQUEST_TEMPLATE.md` | 已就緒 |
| Issue 範本 | `.github/ISSUE_TEMPLATE/` | 檔案已就緒；需在 Settings 開啟 Issues |
| Copilot 指示 | `.github/copilot-instructions.md` | 已就緒 |
| GPT 自訂指令 | `applications/ai-assistants/chatgpt-custom-instructions.md` | 已就緒（含 Keep 規則） |
| Keep ↔ GPT 協定 | `docs/KEEP_GPT_SYNC.md` | 已就緒（手動貼上，非 API） |
| 任務板 | `docs/TASK_BOARD.md` | 已就緒（Issues 關閉時使用） |

## 你需要在 GitHub 網頁手動開的開關

本 agent **沒有** repository admin 權限，下列請你用瀏覽器完成（約 1 分鐘）：

1. 開啟倉庫 **Settings → General → Features → Issues**  
2.（建議）開啟 **Discussions**，給 ChatGPT 長討論用  
3. 確認你的 Cursor / GitHub App 對此 repo 有 **Contents + Pull requests** 寫入權限

開啟 Issues 後，可直接用「任務／錯誤／文件」三種範本開議題；任務板可逐步遷移到 Issues。

## 與現有開放工作的同步

| # | 項目 | 備註 |
|---|------|------|
| #2 / #3 | 串流穩定度 + GitHub↔GPT 同步 | 已合併進 `main` |
| Keep 同步 | `docs/KEEP_GPT_SYNC.md` + ChatGPT 指示更新 | 見進行中的 PR／任務板 T-020 |
| main | Cursor Mobile iOS 客戶端 + AI 工作流程文件 | 目前基準線 |

## 不要做的事

- 不要在對話裡貼 API key、token、憑證  
- 不要假設 iPhone 能跑 Xcode／Simulator  
- 不要在未授權時 merge、force-push、刪除分支或改 repo 設定  
