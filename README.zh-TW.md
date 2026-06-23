# 🩺 rails-health-audit

[English](README.md) | **繁體中文**

找出 legacy 或剛接手的 Rails codebase 裡**不健康**的地方，把它變成一份
**排好嚴重度、先修哪個**的 action plan——「用工具 _Y_ 找出問題 _X_，再用方法 _Z_ 修」，
最嚴重的排前面。

它編排那些公認的工具（brakeman、bundler-audit、rubycritic 等），再加上 static 工具與
CI 都做不到的 **runtime 資料正確性檢查**（缺 FK / index / `NOT NULL`）——而且對你的專案
**零足跡**。打包成 [Claude Code](https://claude.com/claude-code) skill，但核心只是一支
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

**在 Claude Code 裡（最簡單）**——直接用白話講：

> 「幫我檢查這個 Rails 專案的健康度」

這一句就會自動幫你走完**下面的步驟一到三**——掃描、填好 Action plan、匯出 PDF。
（或用斜線指令明確叫它：`/rails-health-audit /path/to/rails/project`。）

**獨立使用**的話，三步驟從程式碼走到一份排好優先序的報告：

### 步驟一——掃描
一道指令會先跑靜態掃描，再盡力（best-effort）跑 runtime 掃描——後者只有在 app 能對已
migrate 的資料庫開機時才跑（否則自動跳過，報告會說明怎麼啟用；想把 runtime 結果一起併進來，
先把 DB 設定好）：

```sh
bash scripts/audit.sh /path/to/rails/project
```

它會產出**單一報告**——分「1. Overview」「2. Action plan」「3. Still to run」三節，
runtime 結果會併進 Overview——外加每個工具的原始輸出，都放在一個 per-run 資料夾：

```
<project>/tmp/health-audit/report-<timestamp>/   # git-ignored，是產物
├── health-audit-report.md       # 報告本體（可編輯的來源，你拿來行動的那份）
├── health-audit-report.pdf      # 可分享版，步驟三產生
└── raw_original_result/         # 完整原始輸出：brakeman.txt …＋ active_record_doctor.txt、lol_dba.txt（runtime）
```

### 步驟二——填 Action plan（判斷的那一步）
讀那些 raw log，把 **Action plan** 表填好：每個 🔴/🟡 finding 一列、最嚴重的排前面、
各自標上 `file:line` 跟原始來源。這就是這個 skill 存在的價值。在 Claude Code 裡這步會幫你做。

### 步驟三——匯出 PDF
計畫填好後：

```sh
bash scripts/export.sh /path/to/rails/project
```

會把 `health-audit-report.md` 轉成 `health-audit-report.pdf`（`.md` 仍是可編輯的來源）。

**想先看跑完長怎樣**——repo 內附一份已填好的範例：
**[📄 範例 health-audit-report.pdf](examples/example-unhealthy-project/tmp/health-audit/report-20260623-154905/health-audit-report.pdf)**
（Overview + 已完整填好的 Action plan），由
[markdown 來源](examples/example-unhealthy-project/tmp/health-audit/report-20260623-154905/health-audit-report.md)匯出。

---

## 🧪 用內附的範例試跑

repo 內附一個**真的、故意寫壞**的 Rails 8 app（`example-unhealthy-project`），它真的能
`bundle install`——所以每個工具（包含 license_finder、bundle outdated）都會跑出真實結果，
不會出現「skipped」。把 audit 指過去，再照上面的步驟二、三做（填 Action plan，然後
`export.sh` → 打開 PDF）：

```sh
bash scripts/audit.sh examples/example-unhealthy-project
```

範例裡植入了哪些問題，見
[`examples/example-unhealthy-project/README.md`](examples/example-unhealthy-project/README.md)；
或直接預覽已提交的
[📄 範例報告](examples/example-unhealthy-project/tmp/health-audit/report-20260623-154905/health-audit-report.pdf)
（上方 **使用方式** 段也有連結）。

一份真實案例的完整解說（一個 legacy Rails 4.1 app）在
[`docs/case-study-legacy-rails.zh-TW.md`](docs/case-study-legacy-rails.zh-TW.md)。

---

## ⚠️ 限制

- runtime 掃描把資料正確性與索引檢查自動化了，但 N+1 與覆蓋率仍需 app 被**實際執行到**
  （請求 / 測試），所以那兩項維持手動。
- `bundle outdated` 需要專案自己的 Ruby；當環境 Ruby 與專案釘死的版本不符時，
  會跳過並附註說明。
- 這工具負責評估與規劃，**永遠不會改你的程式碼**——那個決定留給人。

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

這個 audit 分兩輪跑。

**第一輪 · 靜態掃描——讀程式碼**——自動執行，隨時都安全。
它只「讀」你的原始碼和 gem 清單：不啟動 app、不碰資料庫、不裝任何東西。很快，對任何
專案都能隨時安全地跑。涵蓋安全、授權、可維護性、慣例、技術債。（工具優先用你已安裝的，
沒有就用 `gem exec` 即時抓下來跑——需要 Ruby 3.2+。）

**第二輪 · runtime 掃描——把 app 跑起來**——盡力執行，需要已 migrate 的資料庫。
有三件事光讀程式碼查不出來：

| 問題 | 工具 | 在這個 skill 裡 |
|------|------|----------------|
| 資料庫有沒有撐住 model 的假設？（FK、`NOT NULL`、unique、索引）| `active_record_doctor`、`lol_dba` | ✅ 自動跑 |
| 有沒有拖垮效能的 N+1 查詢？ | `bullet` / `prosopite` | ⏳ 手動——需要 app 被實際執行到 |
| 測試到底覆蓋了多少？ | `simplecov` | ⏳ 手動——需要跑測試套件 |

自動的那組會透過**暫時的** bundle（`scripts/audit-dynamic.sh`）跑，所以完全不動你的
`Gemfile` / `Gemfile.lock`。手動的那兩項只有在實際跑到的 code path 才驗得到，所以維持成
文件化的待辦。

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

## 📄 授權

MIT——見 [LICENSE](LICENSE)。
