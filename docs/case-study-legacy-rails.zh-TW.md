# 案例解說：替一個 legacy Rails 4.1 app 做健檢

[English](case-study-legacy-rails.md) | **繁體中文**

我把 `rails-health-audit` 指向一個真實的 legacy codebase——一個 Rails **4.1** /
Ruby **2.3.5** 的應用，約 2.4 萬行、433 個檔案、101 個 gem。Rails 4.1 已經
end-of-life 好幾年，所以我本來就預期它不健康。有趣的點從來不是「它爛不爛」——
而是當掃描結果**整片紅**的時候，**你第一個要修什麼**。

## 原始數字

一個指令，幾分鐘：

```sh
bash scripts/audit-static.sh /path/to/app
```

| 順位 | 類別 | 工具 | 結果 |
|------|------|------|------|
| 1 | 安全 | brakeman | **84** 個警告（46 SQL injection、9 命令注入、9 CSRF…）|
| 1 | 安全 | bundler-audit | **170** 個漏洞 gem advisory（11 Critical、65 High、61 Medium）|
| 3 | 效能 | fasterer | 104 條建議 |
| 4 | 可維護性 | rubycritic | 分數 **72.5** / 100、**4,562** 個 smell |
| 4 | 可維護性 | rubocop | **9,321** 個 offense |
| 4 | Rails 慣例 | rails_best_practices | **449** 條警告 |
| 5 | 技術債 | bundle outdated | 跳過（釘死 Ruby 2.3.5）|

一萬一千條 finding。如果你從清單最上面一條一條往下做，你會在 RuboCop 上耗掉一個月、
卻一直碰不到那個 SQL injection。所以這工具的價值不在數字——而在**接下來的排序**。

## 優先序是怎麼決定的

四條規則，依序套用。沒有一條是「數字最大的先做」。

**1. 商業衝擊勝過數量。** 一個 SQL injection 能讓公司上新聞；9,321 個風格問題不會。
固定順序是 _安全 → 資料正確性 → 效能 → 可維護性 → 風格_。

**2. 用 confidence / criticality 砍掉雜訊。** brakeman 報了 84 個，但只有 **13** 個是
High-confidence——45 個是「Weak」、在老 code 上多半是誤報。先修那 13 個。依賴那邊也一樣：
先處理 **11 個 Critical + 65 個 High**，不是一次 170 個全做。

**3. 找出「修一個解掉一整欄」的那一刀。** 那 170 個 advisory 不是 170 件工作——它們
擠在少數幾個老 gem 上：`nokogiri`（37）、`rack`（36）、Rails 核心（約 24）、
`puma`（12）。把 Rails 從 4.1 升到受支援的版本、再 `bundle update`，一個計畫好的動作就
溶掉它們的一大半——包含大部分 Critical。這是整份報告裡槓桿最高的一招。

**4. 風險與安全網決定先後。** 大型框架升級在沒有測試接住回歸時很危險。這個 app 剛好有
約 293 個 spec，所以第 0 步是：**先**把它們跑綠、接進 CI，再在那張安全網後面做有風險的
升級。

## 排出來的計畫

- **Step 0 — 安全網。** 跑既有的 spec、跑綠、接進 CI。在這之前不做任何有風險的事。
- **Step 1 — 13 個 High-confidence 安全洞。** 把拼接的 SQL 參數化、堵住命令注入的入口。
  小改動、低風險、高價值。
- **Step 2 — 把 Rails 升出 4.1 + `bundle update`。** 槓桿最高的單一動作；清掉 170 個
  advisory 的大半與那些 Critical。分階段進行，在 Step 0 的安全網後面做。
- **Step 3 — Rails 升級沒蓋到的漏洞 gem**（nokogiri、puma、devise…）：個別升級。
- **Step 4 — 可維護性，挑著做。** `rubocop -a` 幾乎零成本清掉數千個瑣碎 offense；
  接著只重構 RubyCritic 標出最差的那幾個檔案，以及 21 個 `rescue Exception`
  （它們會吞掉真正的 bug）。
- **Step 5 — 慣例與微效能，順手做。** 肥 controller 和 fasterer 的建議，等你正好改到
  那段 code 時順手處理——不開專門的 sprint。
- **Step 6 — 鎖進 CI。** 把 brakeman + bundler-audit + rubocop 設一個 baseline 接進 CI，
  讓清理過的東西不會悄悄退步。

## 重點

靜態掃描是診斷，不是解藥。在 legacy codebase 裡真正重要的能力不是「會跑工具」——
那誰都會——而是讀完一萬一千條 finding，能講出理由地說：「做這六件事，照這個順序。」
這裡最大的贏面，是一個直擊根因的動作（升級 Rails）——而那在一份照數量排序的清單裡，
會被埋到第四十頁。
