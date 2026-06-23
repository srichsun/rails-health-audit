# Rails Health Audit — example-unhealthy-project

_Generated 2026-06-23 15:49. Static scan + (best-effort) runtime checks. Full raw tool output is in `raw_original_result/`._

## 1. Overview (every check, most severe first)

| Priority | Category | Tool | Finding | Raw output |
|----------|----------|------|---------|------------|
| 🔴 1 | Security | brakeman | 4 warning(s) | `raw_original_result/brakeman.txt` |
| 🔴 1 | Security | bundler-audit | 8 vulnerable advisory(ies) | `raw_original_result/bundler-audit.txt` |
| 🔴 1 | Compliance | license_finder | 73 | `raw_original_result/license_finder.txt` |
| 🔴 2 | Data correctness | active_record_doctor | 7 issue(s) | `raw_original_result/active_record_doctor.txt` |
| 🟡 3 | Performance | fasterer | 5 speed suggestion(s) | `raw_original_result/fasterer.txt` |
| 🟡 3 | Performance | lol_dba | 2 missing index(es) | `raw_original_result/lol_dba.txt` |
| 🟡 4 | Maintainability | rubycritic | score 95.48, 31 smell(s) | `raw_original_result/rubycritic.txt` |
| 🟡 4 | Rails conventions | rails_best_practices | 19 warning(s) | `raw_original_result/rails_best_practices.txt` |
| ⚪ 4 | Maintainability | rubocop | 27 offense(s) | `raw_original_result/rubocop.txt` |
| ⚪ 4 | Maintainability | erb_lint | 8 ERB offense(s) | `raw_original_result/erb_lint.txt` |
| ⚪ 5 | Tech debt | bundle outdated | 2 | `raw_original_result/outdated.txt` |

Legend — 🔴 must fix (security / data) · 🟡 should fix (correctness / maintainability) · ⚪ nice to have (style / freshness).

> **A ⚠️ skipped check is NOT a pass.** It means the tool could not run in this
> environment, not that there is nothing wrong. license_finder needs a real
> `bundle install`; bundle outdated needs the project's own Ruby (this run used a
> different Ruby than the project pins). Re-run both in the project's environment
> to get a real result.

## 2. Action plan

> **How to read this — cut noise with confidence/criticality:** static tools
> over-report. brakeman tags each warning High / Medium / Weak confidence — fix the
> **High** ones first; Weak ones are often false positives. bundler-audit tags each
> advisory Critical / High / Medium — triage **Critical/High**, don't treat all 100+
> as equal. So a raw count (e.g. "137 advisories") is a starting point, not 137
> separate jobs.

_Severity first. Cover every 🔴 and 🟡 finding (one row each); collapse the ⚪
style-level findings into a single row. Use `<br>` for line breaks inside a cell._

| # | Pri | Issue (tool, `file:line`) | Solution | Effort | Raw |
|---|-----|----------------------------|----------|--------|-----|
| 1 | 🔴 | **SQL injection** (brakeman) — `products_controller.rb:8,10`, `views/products/index.html.erb:4`: `Product.where("name LIKE '%#{params[:q]}%'")` and a raw `connection.execute` interpolate params straight into SQL. | Use bind params: `where("name LIKE ?", "%#{params[:q]}%")`; drop the raw `execute` for an AR query. | S | `raw_original_result/brakeman.txt` |
| 2 | 🔴 | **Command injection** (brakeman) — `products_controller.rb:28`: `system("convert #{params[:thumb]} …")` shells out with a user param. | Pass args as a list (`system("convert", path, …)`) and validate/whitelist the input; better, use a Ruby image lib. | S | `raw_original_result/brakeman.txt` |
| 3 | 🔴 | **XSS** (brakeman) — `views/products/index.html.erb`: `params[:q]` rendered unescaped. | Let ERB auto-escape (drop `raw`/`html_safe`/`<%==`); escape with `h` if needed. | S | `raw_original_result/brakeman.txt` |
| 4 | 🔴 | **Vulnerable gems** (bundler-audit) — `jwt 2.3.0` (CVE-2026-45363, High), `rexml 3.2.4` (several High/Medium). | Bump `jwt >= 3.2.0` and `rexml >= 3.2.7`, then `bundle update jwt rexml`. | S | `raw_original_result/bundler-audit.txt` |
| 5 | 🔴 | **Data integrity** (active_record_doctor) — missing unique index on `products.sku`; `NOT NULL` missing on `products.name`, `tags.product_id`; no FKs on `products.owner_id`, `tags.product_id`. | One migration: `add_index … unique`, `change_column_null`, `add_foreign_key` (plus the indexes in #8). | M | `raw_original_result/active_record_doctor.txt` |
| 6 | 🔴 | **License approvals** (license_finder) — 73 deps unapproved. | Almost all MIT/BSD — approve the permissive set once (`license_finder permitted_licenses add MIT "Simplified BSD" …`); review anything else. | M | `raw_original_result/license_finder.txt` |
| 7 | 🟡 | **Slow idioms** (fasterer) — `report.rb:6` `select.first`, `report.rb:16` `reverse.each`, `Hash#fetch` with a 2nd arg in `puma.rb`/`production.rb`. | `detect`, `reverse_each`, and `fetch(k) { default }` block form. | S | `raw_original_result/fasterer.txt` |
| 8 | 🟡 | **Missing indexes** (lol_dba) — no index on `products.owner_id`, `tags.product_id`. | `add_index :products, :owner_id` and `add_index :tags, :product_id` (fold into #5's migration). | S | `raw_original_result/lol_dba.txt` |
| 9 | 🟡 | **Rails conventions** (rails_best_practices) — 19 warnings: Law of Demeter in `index.html.erb`, fat-controller logic, `rescue Exception` at `products_controller.rb:35`, unused `Product`/`Report` methods, unrestricted routes. | Push logic into models, rescue `StandardError`, delete dead methods, scope routes with `only:`. | M | `raw_original_result/rails_best_practices.txt` |
| 10 | 🟡 | **Maintainability** (rubycritic) — score 95.48, 31 smells; `report.rb` worst (5 smells). | Refactor the flagged duplication/complexity, starting with `report.rb`. | M | `raw_original_result/rubycritic.txt` |
| 11 | ⚪ | **Style + freshness** (rubocop 27 / erb_lint 8 / bundle outdated) — mostly autocorrectable; gems jwt & rexml outdated (covered in #4). | `rubocop -A` and `erblint -a` for the autocorrectable set; review the rest. | S | `raw_original_result/rubocop.txt` |

## 3. Still to run manually

Runtime data-correctness & missing-index checks **ran** (2026-06-23 15:49) and are folded into the
Overview and Action plan above — full per-detector output is in
`raw_original_result/active_record_doctor.txt` and `raw_original_result/lol_dba.txt`.

Two checks still need the app *exercised* (not just booted), so run them by hand:

- **N+1 queries** — add `gem "bullet"` (development/test), enable it in
  `config/environments/test.rb`, then run your request/system specs; Bullet logs every N+1.
- **Test coverage** — add `gem "simplecov", require: false` (test), put
  `require "simplecov"; SimpleCov.start "rails"` at the top of your test helper, run the
  suite (`bin/rails test` or `bundle exec rspec`), then open `coverage/index.html`.
