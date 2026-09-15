# Google Keep ↔ ChatGPT / Codex 同步協定

本文件讓 **Google Keep（隨手筆記）**、**ChatGPT / Codex（釐清與派工）**、**GitHub 任務板（可追蹤待辦）** 使用同一套安排。

## 重要限制（先講清楚）

| 能力 | 現況 |
|------|------|
| Cursor / 本倉庫直接讀寫 Google Keep | **做不到**（無 Keep API／MCP） |
| Google Drive MCP | 需你授權；且 **Drive ≠ Keep**，開了也讀不到 Keep 筆記 |
| 可行同步 | 你用手機 **複製／分享** Keep 內容 → GPT／任務板／本倉庫暫存 |

因此「同步」在這裡的意思是：**同一套標籤、格式與流向**，不是背景自動雙向同步。

## 角色分工

| 角色 | 在哪裡 | 負責什麼 |
|------|--------|----------|
| 你 | Google Keep（iPhone） | 隨手記靈感、待辦、一句話需求 |
| ChatGPT / Codex | OpenAI | 把 Keep 筆記整理成目標／範圍／完成定義 |
| Cursor Cloud Agent | 本倉庫 | 只處理已寫進 GitHub／任務板的可執行項 |
| GitHub | `docs/TASK_BOARD.md` 或 Issue | 可追蹤、可審閱的正式待辦 |

## 建議的 Keep 標籤

在 Keep 建立這些標籤（或清單），手機單手也好找：

| Keep 標籤 | 含義 | 下一步 |
|-----------|------|--------|
| `#inbox` | 尚未整理 | 貼給 GPT 分類 |
| `#gpt` | 要給 ChatGPT 處理 | 複製全文給 GPT |
| `#cursor` | 可派 Cursor Agent | GPT 產出交接提示 → Cursor |
| `#github` | 已進任務板／PR | 附上 T-xxx 或 PR 編號 |
| `#done` | 已完成 | 可封存 |

## 標準一回合流程（手機）

```text
Keep 隨手記（加 #inbox 或 #gpt）
        ↓
複製筆記 → 貼進 ChatGPT（可用下方範本）
        ↓
GPT 輸出：一句目標 + 範圍 + 完成定義
        ↓
若要改程式 → 交給 Cursor；並寫進 docs/TASK_BOARD.md
若只是想法 → 留在 Keep，改標籤 #done 或繼續 refinement
```

### 從 Keep 貼給 GPT 的最短範本

```text
這是我的 Google Keep 筆記，請依 docs/KEEP_GPT_SYNC.md 整理。
倉庫：orightimutim-rgb/UTP-Utopia-Universal-Design-Standard

【Keep 原文】
（貼上）

請回覆：
1. 這是靈感／待辦／可派工任務？
2. 若可派工：一句目標 + 範圍 + 完成定義
3. 建議標籤：#cursor / #github / #done
4. 若要給 Cursor：產出交接提示（見 GITHUB_GPT_SYNC.md）
```

### GPT 整理完後，回寫 Keep 的建議格式

在原筆記底部追加（或開新筆記）：

```text
--- GPT ---
類型：任務
目標：……
範圍：……
完成定義：……
任務板：T-xxx（若已建）
下一個動作：貼給 Cursor / 僅保留靈感
```

## 可選：倉庫暫存匣（給 agent 讀）

若希望 Cursor 也能讀到某則 Keep 內容，請把筆記貼進：

[`docs/learning/keep-inbox.md`](learning/keep-inbox.md)

規則：

1. 一則筆記一個區塊，含日期與 Keep 標題  
2. **不要**貼密碼、API key、個資  
3. Agent 讀完後可建議是否升級為 `TASK_BOARD` 項目  

## 與 GitHub ↔ GPT 的關係

```text
Keep（靈感層）
  → ChatGPT（整理層）
    → TASK_BOARD / Issue（追蹤層）
      → Cursor PR（實作層）
```

程式與 PR 仍以 [`GITHUB_GPT_SYNC.md`](GITHUB_GPT_SYNC.md) 為準；Keep 不取代 GitHub。

## 不要做的事

- 不要期待 Agent「自動打開你的 Keep」  
- 不要在 Keep／對話貼 secrets  
- 不要把未整理的長筆記直接當 Cursor 任務（先經 GPT 壓縮）  
