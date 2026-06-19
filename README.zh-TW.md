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
| 1 | 授權合規 | 法律 / 授權風險 | `license_finder` | 核可或換掉該 gem |
| 2 | 資料正確性 | 髒資料、資料毀損 | `active_record_doctor`（深掃）| 加 FK / NOT NULL / unique index |
| 3 | 效能 | 變慢、高負載下當機 | `fasterer`（快掃）；`bullet` / `prosopite`、`lol_dba`（深掃）| eager load、加 index、快取 |
| 4 | 可維護性 | 改動慢、改動有風險 | `rubycritic`（reek + flay + flog）、`rubocop`、`rails_best_practices`、`erb_lint` | 抽 service / concern、拆方法 |
| 5 | 技術債新鮮度 | 漏洞與版本漂移累積 | `bundle outdated`、`bundler-audit` | 排程升級 gem |
| 6 | 死碼與覆蓋率 | 隱藏風險、不敢改 | `simplecov`（深掃）| 刪死碼、補測試 |

### 兩輪掃描：先快讀，再深看

這個工具分兩輪跑。

**第一輪——讀程式碼（腳本會自動幫你做）**
它只「讀」你的原始碼和 gem 清單，就這樣。不會啟動你的 app、不碰資料庫、也不會在你
專案裡裝任何東西。所以它對任何專案都能隨時安全地跑，而且很快。這一輪涵蓋：
安全、授權、可維護性、慣例、技術債。（工具優先用你已安裝的，沒有的話用 `gem exec`
即時抓下來跑——需要 Ruby 3.2+。）

**第二輪——把 app 跑起來（腳本只「列出」，不會自己跑）**
有三件事光「讀程式碼」查不出來，一定要把 app 真的跑起來、連上資料庫才知道：

- 資料安不安全？——缺外鍵 / 索引（`active_record_doctor`）
- 有沒有拖垮效能的 N+1 查詢？（`bullet`）
- 測試到底覆蓋了多少程式碼？（`simplecov`）

要跑這些，得在專案裡暫時加一兩個 gem 再啟動，所以工具不替你做，而是把它們當
「下一步待辦」清楚寫進報告裡。

一句話：**第一輪＝讀程式碼（自動、安全、快）；第二輪＝把 app 跑起來，抓讀不出來的問題
（手動跟進）。**

### 每個工具在檢查什麼

**安全與合規**
- **brakeman** — 不執行、只「讀」你的 Rails 程式碼，挑出安全漏洞：SQL injection、
  XSS、不安全的轉址等等。
- **bundler-audit** — 拿你鎖定的 gem 版本，去比對一個已知安全漏洞（CVE）資料庫。
- **license_finder** — 列出你所有依賴 gem 的授權條款，標出專案還沒核可的——
  在重視授權合規的地方很有用。

**資料正確性**（第二輪）
- **active_record_doctor** — 拿你的資料庫跟 model 對照，找出缺的外鍵、索引、
  `NOT NULL`、unique 約束。

**效能**
- **fasterer** — 快速指出寫得慢的 Ruby 寫法。
- **bullet**（第二輪）— 在 app 跑的時候盯著，抓 N+1 查詢。
- **prosopite**（第二輪）— 更嚴格的 N+1 偵測，抓得到 bullet 漏掉的。
- **lol_dba**（第二輪）— 找出被拿來查詢、卻沒有資料庫索引的欄位。

**可維護性**
- **rubycritic** — 給整個 codebase 一個品質總分（A–F）。它底下跑下面三個再合起來：
  - **reek** — 點名「壞味道」：方法太長、命名含糊、一個 class 管太多事。
  - **flog** — 評每個方法有多複雜、多難測試。
  - **flay** — 找複製貼上的重複碼。
- **rubocop** — Ruby 風格與 lint 檢查的事實標準。
- **rails_best_practices** — Rails 專屬建議：肥 controller、該放 model 的邏輯、
  迪米特法則等。
- **erb_lint** — 檢查 ERB view 樣板的排版問題（rubocop 看不到的部分）。

**技術債與覆蓋率**
- **bundle outdated** — 列出落後最新版的 gem。
- **simplecov**（第二輪）— 量你的測試實際跑過多少比例的程式碼。

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
