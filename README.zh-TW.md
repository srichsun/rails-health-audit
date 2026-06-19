# rails-health-audit

[English](README.md) | **繁體中文**

一套可重複使用的方法，用來評估既有 Rails 專案的健康度，並把結果轉成一份
**排好優先序的改善計畫**——「用工具 _Y_ 找出問題 _X_，再用方法 _Z_ 修復」，
依嚴重程度由高到低排列。

它打包成一個 [Claude Code](https://claude.com/claude-code) skill，但核心只是一支
可以單獨執行的 shell 腳本。

---

## 為什麼做這個

成熟的 Rails 系統會累積技術債：安全漏洞、缺漏的資料庫約束、N+1 查詢、重複的程式碼，
以及落後好幾年的 gem。Ruby 生態系針對每一項其實都有很好的工具（brakeman、
bundler-audit、rubocop、rubycritic……）。真正缺的是疊在它們之上的**判斷層**：

- 在 9,000 條 finding 裡，哪些才真的重要？
- 我**第一個**該修什麼？
- 能不能對下一個專案跑同一套評估，而不用每次重新想一遍？

`rails-health-audit` 就是這個判斷層。它**不是**又一個 linter——它編排這些公認的工具、
依**商業影響**排序它們的輸出，產出一份團隊能直接執行的計畫。

---

## 運作原理

### 嚴重度模型

Finding 依「它威脅到什麼」排序，**而不是**依數量。一個 SQL injection 的優先序，
高過一萬個風格問題。

| 順位 | 類別 | 威脅到什麼 | 工具（_Y_）| 典型修法（_Z_）|
|------|------|-----------|-----------|----------------|
| 1 | 安全 | 入侵、資料外洩 | `brakeman`、`bundler-audit` | 修補、升級、淨化輸入 |
| 2 | 資料正確性 | 髒資料、資料毀損 | `active_record_doctor`（runtime）| 加 FK / NOT NULL / unique index |
| 3 | 效能 | 變慢、高負載下當機 | `fasterer`（靜態）；`bullet` / `prosopite`、`lol_dba`（runtime）| eager load、加 index、快取 |
| 4 | 可維護性 | 改動慢、改動有風險 | `rubycritic`（reek + flay + flog）、`rubocop`、`rails_best_practices` | 抽 service / concern、拆方法 |
| 5 | 技術債新鮮度 | 漏洞與版本漂移累積 | `bundle outdated`、`bundler-audit` | 排程升級 gem |
| 6 | 死碼與覆蓋率 | 隱藏風險、不敢改 | `simplecov`（runtime）| 刪死碼、補測試 |

### 兩個階段

**第一階段——靜態掃描**（腳本自動化的部分）：跑那些只需要原始碼 + `Gemfile.lock`
的工具。不啟動 app、不連資料庫、也不在專案裡永久安裝任何東西——工具優先用已安裝的
binary，否則退而用 `gem exec`（Ruby 3.2+）。

**第二階段——runtime 檢查**（寫在報告裡）：那三項需要 app 啟動並連上資料庫才驗得到的
檢查——資料正確性（`active_record_doctor`）、N+1（`bullet`）、覆蓋率（`simplecov`）。
這些以「後續待辦」列出而非自動執行，因為它們需要在目標專案裡暫時加上 gem。

### 跟 CI、跟 rubycritic 差在哪

- **vs. CI**：CI 在每次 push 時把關**這次的 diff**——它擋住**新**問題。這個工具評估的是
  **整個既有 codebase**，定期掃，把**累積**的舊債盤點出來並排序。兩者互補：audit 找出債，
  你再把對應的檢查接進 CI，讓它不會復發。
- **vs. rubycritic / rails_code_auditor**：那些工具跑檢查、報 metric。這個多了嚴重度排序、
  靜態工具包略過的 runtime 階段，以及把原始輸出轉成優先序計畫的那一步。

---

## 安裝

當成 Claude Code skill：

```sh
git clone https://github.com/<you>/rails-health-audit ~/.claude/skills/rails-health-audit
```

Claude Code 會自動偵測。接著你可以請 Claude「audit 這個 Rails 專案的健康度」，
或直接跑腳本（見下）。

獨立使用（不需要 Claude Code）：

```sh
git clone https://github.com/<you>/rails-health-audit
```

需求：Ruby 3.2+（為了 `gem exec`）。分析工具會在需要時自動抓取。

---

## 使用方式

```sh
bash scripts/audit.sh /path/to/rails/project
```

它會把排序後的報告寫到 `<project>/tmp/health-audit/REPORT.md`，並把每個工具的
完整原始輸出寫到 `<project>/tmp/health-audit/raw/`。摘要會印在終端機。

接著做分流（triage）：讀那些 raw log、挑出影響最大的前幾項，把報告裡的
**Action plan** 區塊填好——每行一條：`[類別] 問題 → 修法 → 工時`。
（在 Claude Code 裡，這個分流步驟可以直接從 raw log 幫你完成。）

---

## 用內附的範例試跑

repo 內附一個極小、**故意寫壞**、長得像 Rails 的 app，讓你不必拿自己的 code，
就能看到 audit 亮起來：

```sh
bash scripts/audit.sh examples/legacy_blog
cat examples/legacy_blog/tmp/health-audit/REPORT.md
```

範例裡植入了哪些問題，見
[`examples/legacy_blog/README.md`](examples/legacy_blog/README.md)。

一個真實世界的走查（一個 legacy Rails 4.1 app）在
[`docs/case-study-legacy-rails.md`](docs/case-study-legacy-rails.md)。

---

## 限制

- 第一階段只做靜態。runtime 檢查（順位 2，以及順位 3 的 N+1 部分）是文件化、未執行。
- `bundle outdated` 需要專案自己的 Ruby；當環境 Ruby 與專案釘死的版本不符時，
  會跳過並附註說明。
- 這工具負責評估與規劃，**永遠不會改你的程式碼**——那個決定留給人。

## 授權

MIT——見 [LICENSE](LICENSE)。
