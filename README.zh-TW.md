# 🩺 rails-health-audit

[English](README.md) | **繁體中文**

一套可重複使用的方法，用來評估既有 Rails 專案的健康度，並把結果轉成一份
**排好優先序的改善計畫**——「用工具 _Y_ 找出問題 _X_，再用方法 _Z_ 修復」，
依嚴重程度由高到低排列。

它打包成一個 [Claude Code](https://claude.com/claude-code) skill，但核心只是一支
可以單獨執行的 shell 腳本。

---

## 🤔 為什麼做這個

成熟的 Rails 系統會累積技術債：安全漏洞、缺漏的資料庫約束、N+1 查詢、重複的程式碼，
以及落後好幾年的 gem。Ruby 生態系針對每一項其實都有很好的工具（brakeman、
bundler-audit、rubocop、rubycritic……）。真正缺的是疊在它們之上的**判斷層**：

- 在 9,000 條 finding 裡，哪些才真的重要？
- 我**第一個**該修什麼？
- 能不能對下一個專案跑同一套評估，而不用每次重新想一遍？

`rails-health-audit` 就是這個判斷層。它**不是**又一個 linter——它編排這些公認的工具、
依**商業影響**排序它們的輸出，產出一份團隊能直接執行的計畫。

---

## 🎯 什麼時候用、什麼時候別用

**適合：**
- 你接手 / onboard 一個不是自己寫的 codebase，想快速摸清它的弱點。
- 專案是 legacy、沒有 CI，或只有半套 CI。
- 你要規劃重構 / 清理，需要一份排好優先序的待辦，而不是 pass/fail 閘門。
- 你要對一個系統做一次性評估——盡職調查，或團隊剛接手別人的 app。
- 你想要多數 CI 沒在跑的 runtime 資料正確性 / N+1 檢查。

**不適合：**
- 專案已有成熟 CI、每個 PR 都跑這些檢查——再重跑 static 的部分價值很低。
- 你要的是 merge 閘門：那是 CI 的工作（擋 diff）。這工具產出的是「拿來排優先序的報告」，
  不是 build 的紅/綠。
- 你期望它取代 CI。它是定期盤點、不是持續把關——兩者互補：這個找出舊債，CI 防止它復發。

---

## ⚙️ 運作原理

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

**第二輪——把 app 跑起來**
有三件事光「讀程式碼」查不出來，一定要把 app 真的跑起來、連上已 migrate 的資料庫才知道：

- 資料安不安全？——缺外鍵、索引、`NOT NULL`、unique 約束（`active_record_doctor`、`lol_dba`）
- 有沒有拖垮效能的 N+1 查詢？（`bullet` / `prosopite`）
- 測試到底覆蓋了多少程式碼？（`simplecov`）

`scripts/audit-dynamic.sh` 把第一組自動化了：它啟動 app、用**暫時的** bundle 跑資料正確性與索引
偵測器，**完全不動你的 `Gemfile` / `Gemfile.lock`**。N+1 與覆蓋率那兩項還需要 app 被
**實際執行到**（請求或測試），只有跑到的 code path 才驗得到，所以維持成文件化的待辦。

一句話：**第一輪＝讀程式碼（隨時都能安全跑）；第二輪＝把 app 開機、抓讀不出來的問題
（需要 DB 設定好）。**

### 每個工具在檢查什麼

| 類別 | 工具 | 檢查什麼 |
|------|------|----------|
| 安全 | [**brakeman**](https://github.com/presidentbeef/brakeman) | 不執行、只「讀」Rails 程式碼，挑安全漏洞——SQL injection、XSS、不安全的轉址 |
| 安全 | [**bundler-audit**](https://github.com/rubysec/bundler-audit) | 拿你鎖定的 gem 版本去比對已知漏洞（CVE）資料庫 |
| 合規 | [**license_finder**](https://github.com/pivotal/LicenseFinder) | 列出每個 gem 的授權，標出專案還沒核可的 |
| 資料正確性 | [**active_record_doctor**](https://github.com/gregnavis/active_record_doctor)（第二輪）| 資料庫有沒有真的撐住 model 假設的限制——缺的外鍵、索引、`NOT NULL`、unique 約束 |
| 效能 | [**fasterer**](https://github.com/DamirSvrtan/fasterer) | 寫得慢的 Ruby 寫法（快速靜態提示）|
| 效能 | [**bullet**](https://github.com/flyerhzm/bullet)（第二輪）| app 跑起來時抓 N+1 查詢 |
| 效能 | [**prosopite**](https://github.com/charkost/prosopite)（第二輪）| N+1 查詢，比 bullet 更嚴格 |
| 效能 | [**lol_dba**](https://github.com/plentz/lol_dba)（第二輪）| 被拿來查詢、卻沒有資料庫索引的欄位 |
| 可維護性 | [**rubycritic**](https://github.com/whitesmith/rubycritic) | 品質總分（A–F）；底下跑下面三個再合起來 |
| 可維護性 | ↳ [**reek**](https://github.com/troessner/reek) | 壞味道——方法太長、命名含糊、一個 class 管太多事 |
| 可維護性 | ↳ [**flog**](https://github.com/seattlerb/flog) | 每個方法有多複雜、多難測試 |
| 可維護性 | ↳ [**flay**](https://github.com/seattlerb/flay) | 複製貼上的重複碼 |
| 可維護性 | [**rubocop**](https://github.com/rubocop/rubocop) | Ruby 風格與 lint 的事實標準 |
| 可維護性 | [**rails_best_practices**](https://github.com/flyerhzm/rails_best_practices) | Rails 專屬建議——肥 controller、該放 model 的邏輯、迪米特法則 |
| 可維護性 | [**erb_lint**](https://github.com/Shopify/erb-lint) | ERB view 樣板——預設查排版一致性，另可開啟不安全輸出（XSS）檢查；rubocop 看不到 ERB |
| 技術債 | [**bundle outdated**](https://bundler.io/man/bundle-outdated.1.html) | 落後最新版的 gem |
| 覆蓋率 | [**simplecov**](https://github.com/simplecov-ruby/simplecov)（第二輪）| 你的測試實際跑過多少比例的程式碼 |

> 想建立授權合規治理？見一份附完整註解的範例設定
> [`docs/license_finder.sample.yml`](docs/license_finder.sample.yml)。

### 跟 CI、跟 rubycritic 差在哪

- **vs. CI**：CI 在每次 push 時把關**這次的 diff**——它擋住**新**問題。這個工具評估的是
  **整個既有 codebase**，定期掃，把**累積**的舊債盤點出來並排序。兩者互補：audit 找出債，
  你再把對應的檢查接進 CI，讓它不會復發。
- **vs. rubycritic / rails_code_auditor**：那些工具跑檢查、報 metric。這個多了嚴重度排序、
  靜態工具包略過的 runtime 階段，以及把原始輸出轉成優先序計畫的那一步。

---

## 🧭 跟其他工具的比較

市面上健康度工具很多，這個不是要贏過它們，而是補一個**特定 niche**。獨特之處在**組合**：
Rails 專屬檢查 **＋** runtime 資料正確性 **＋** 零足跡——不是單一功能。

| 工具 | 懂 Rails | runtime 資料正確性¹ | 在哪跑 |
|------|:-------:|:------------------:|--------|
| **rails-health-audit**（本工具）| ✅ | ✅ `active_record_doctor`、`lol_dba` | 本機 / Claude Code——不動專案 |
| rails_code_auditor | ✅ | ❌ 只有 static | 裝進專案的 gem |
| rails_code_health · rails-audit | ✅ | ❌ 只有 static | 裝進專案的 gem |
| CodeScene | ❌ 語言無關² | ❌ | 商業 SaaS |
| DeepSource | ❌ Ruby analyzer，非 Rails 框架 | ❌ | SaaS |
| SonarQube | ❌ 多語言 | ❌ | SaaS / 自架 |
| Tech Debt Reviewer（Claude skill）| ❌ 語言無關 | ❌ | Claude Code |

¹ 啟動 app、檢查「資料庫有沒有撐住 model 假設的限制」——缺外鍵、`NOT NULL`、unique index。
² CodeScene、DeepSource、SonarQube **都支援** Ruby，但是用通用方式分析，不懂 Rails /
ActiveRecord 的慣例。

它不取代上面任何一個——已經在用 CodeScene 或有成熟 CI 的團隊覆蓋率很高了。它的定位是：
**一個輕量、懂 Rails、零足跡的評估，讓你能對一個剛接手的 codebase 馬上跑一遍。**

**出處：** [2026 最佳 Code Health 工具（repowise）](https://www.repowise.dev/blog/comparisons/best-code-health-tools-2026)
· [2026 10 大 Code Audit 工具（Panto）](https://www.getpanto.ai/blog/best-code-audit-tools)
· [2026 技術債工具（CodeAnt）](https://www.codeant.ai/blogs/tools-measure-technical-debt)
· [CodeScene 語言支援](https://docs.enterprise.codescene.io/latest/usage/language-support.html)
· [DeepSource Ruby（GA）](https://deepsource.com/blog/ruby-general-availability-release/)
· [SonarQube Ruby](https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/languages/ruby/)

---

## 📦 安裝

當成 Claude Code skill：

```sh
git clone https://github.com/srichsun/rails-health-audit ~/.claude/skills/rails-health-audit
```

Claude Code 會自動偵測。接著你可以請 Claude「audit 這個 Rails 專案的健康度」，
或直接跑腳本（見下）。

獨立使用（不需要 Claude Code）：

```sh
git clone https://github.com/srichsun/rails-health-audit
```

需求：Ruby 3.2+（為了 `gem exec`）。分析工具會在需要時自動抓取。

> **為什麼用 `gem exec`？** 它能「借來跑」每個工具、但不永久安裝。所以你不必事先
> `gem install` 這一整套工具，也不會在你的系統 gem 或專案的 `Gemfile` 裡留下任何東西——
> 整個 audit 自給自足、跑完不留痕跡、不污染環境。`gem exec` 是 Ruby 3.2+ 內建
> RubyGems 才有的功能，這也是最低版本要 3.2 的原因。

---

## 🚀 使用方式

**在 Claude Code 裡（最簡單）。** 直接用白話講，Claude 會自動拿出這個 skill、
跑掃描、還幫你排優先序：

> 「幫我檢查這個 Rails 專案的健康度」

或用斜線指令明確叫它：

```
/rails-health-audit /path/to/rails/project
```

**獨立使用——一道指令。** 直接跑（不需要 Claude Code）：

```sh
bash scripts/audit.sh /path/to/rails/project
```

`audit.sh` 會先跑靜態掃描，接著盡力（best-effort）跑 runtime 掃描——只有在 app 能開機、
而且資料庫已 migrate 時才跑；否則 runtime 階段會自動跳過，報告裡也會說明怎麼啟用它。
（它內部會呼叫 `audit-static.sh` 與 `audit-dynamic.sh`，但你要跑的指令是 `audit.sh`。）

不管哪種方式，它都會把排序後的單一報告寫到
`<project>/tmp/health-audit/report-<timestamp>/health-audit-report.md`，並把每個工具的
完整原始輸出寫到該次的 `raw_original_result/`。摘要會印在終端機。

接著排優先序（triage）：讀那些 raw log、挑出影響最大的前幾項，把報告裡的
**Action plan** 區塊填好——每行一條：`[類別] 問題 → 修法 → 工時`。
（在 Claude Code 裡，這個排優先序的步驟可以直接從 raw log 幫你完成。）

想把 runtime（第二輪）結果一起併進報告，請在跑 `audit.sh` 前先把專案的資料庫設定好、
migrate 好；如果 DB 還沒準備好，runtime 階段會被跳過，報告裡只會有靜態結果。

---

## 📁 產出檔案在哪

全部都產在 `<project>/tmp/health-audit/` 底下（git-ignored，是產物）。腳本跑完也會在
終端機印出報告路徑。

每次跑都帶 timestamp，各自一個 `report-<timestamp>/` 資料夾，新的一次不會蓋掉舊的——
留著就能前後對比 diff。

```
<project>/tmp/health-audit/
└── report-<timestamp>/                  # 一次跑一個資料夾
    ├── health-audit-report.md           # 工作來源：總覽 + Action plan + 第三節 runtime 檢查
    ├── health-audit-report.pdf           # 可分享的成品（由 export.sh 產生）
    └── raw_original_result/             # 每個工具的完整原始輸出
        ├── brakeman.txt
        ├── bundler-audit.txt
        ├── license_finder.txt
        ├── rubocop.txt
        ├── erb_lint.txt
        ├── rubycritic.txt
        ├── fasterer.txt
        ├── rails_best_practices.txt
        └── outdated.txt
```

`health-audit-report.md` 是你拿來讀、拿來行動的那份。它有三節——「## 1. Overview」、
「## 2. Action plan」、「## 3. Phase 2 — runtime checks」——runtime 結果會併進 Overview
表格與第三節。每條 Action plan 都標了 `file:line` 跟它來自哪個 `raw_original_result/…txt`，
所以每個發現都可以追溯。

想要可分享的檔案？`bash scripts/export.sh <project>` 會把 `health-audit-report.md`
轉成 `health-audit-report.pdf`（`.md` 仍是可編輯的來源）。

---

## 🧪 用內附的範例試跑

repo 內附一個**真的、故意寫壞**的 Rails 8 app（`example-unhealthy-project`），它真的能
`bundle install`——所以每個工具（包含 license_finder、bundle outdated）都會跑出真實結果，
不會出現「skipped」。把 audit 指過去：

```sh
bash scripts/audit.sh examples/example-unhealthy-project
open examples/example-unhealthy-project/tmp/health-audit/report-*/health-audit-report.pdf
```

範例裡植入了哪些問題，見
[`examples/example-unhealthy-project/README.md`](examples/example-unhealthy-project/README.md)；
或者不用跑，直接看已提交的輸出快照
[`examples/example-unhealthy-project/tmp/health-audit/`](examples/example-unhealthy-project/tmp/health-audit/)
（一份 Action plan 已填好的 `report-<timestamp>/health-audit-report.pdf`）。

一份真實案例的完整解說（一個 legacy Rails 4.1 app）在
[`docs/case-study-legacy-rails.zh-TW.md`](docs/case-study-legacy-rails.zh-TW.md)。

---

## ⚠️ 限制

- `audit-dynamic.sh` 把資料正確性與索引檢查自動化了，但 N+1 與覆蓋率仍需 app 被**實際執行到**
  （請求 / 測試），所以那兩項維持手動。
- `bundle outdated` 需要專案自己的 Ruby；當環境 Ruby 與專案釘死的版本不符時，
  會跳過並附註說明。
- 這工具負責評估與規劃，**永遠不會改你的程式碼**——那個決定留給人。

## 📄 授權

MIT——見 [LICENSE](LICENSE)。
