# Rails Health Audit — example-unhealthy-project

_Generated 2026-06-23 15:49. Static scan + (best-effort) runtime checks. Full raw tool output is in `raw_original_result/`._

## 1. Overview (every check, most severe first)

| Priority | Category | Tool | Finding | Raw output |
|----------|----------|------|---------|------------|
| 🔴 1 | Security | brakeman | 4 warning(s) | `raw_original_result/brakeman.txt` |
| 🔴 1 | Security | bundler-audit | 8 vulnerable advisory(ies) | `raw_original_result/bundler-audit.txt` |
| 🔴 1 | Compliance | license_finder | 73 | `raw_original_result/license_finder.txt` |
| 🟡 3 | Performance | fasterer | 5 speed suggestion(s) | `raw_original_result/fasterer.txt` |
| 🟡 4 | Maintainability | rubycritic | score 95.48, 31 smell(s) | `raw_original_result/rubycritic.txt` |
| 🟡 4 | Rails conventions | rails_best_practices | 19 warning(s) | `raw_original_result/rails_best_practices.txt` |
| ⚪ 4 | Maintainability | rubocop | 27 offense(s) | `raw_original_result/rubocop.txt` |
| ⚪ 4 | Maintainability | erb_lint | 8 ERB offense(s) | `raw_original_result/erb_lint.txt` |
| ⚪ 5 | Tech debt | bundle outdated | 2 | `raw_original_result/outdated.txt` |
| 🔴 2 | Data correctness | active_record_doctor | 7 issue(s) | `raw_original_result/pass2_ar_doctor.txt` |
| 🟡 3 | Performance | lol_dba | 2 missing index(es) | `raw_original_result/pass2_lol_dba.txt` |

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
| 1 | 🔴 | … | … | S/M/L | `raw_original_result/…txt` |
| 2 | 🟡 | … | … | S/M/L | `raw_original_result/…txt` |
| 3 | ⚪ | … | … | S/M/L | `raw_original_result/…txt` |

## 3. Still to run manually

Runtime data-correctness & missing-index checks **ran** (2026-06-23 15:49) and are folded into the
Overview and Action plan above — full per-detector output is in
`raw_original_result/pass2_ar_doctor.txt` and `raw_original_result/pass2_lol_dba.txt`.

Two checks still need the app *exercised* (not just booted), so run them by hand:

- **N+1 queries** — add `gem "bullet"` (development/test), enable it in
  `config/environments/test.rb`, then run your request/system specs; Bullet logs every N+1.
- **Test coverage** — add `gem "simplecov", require: false` (test), put
  `require "simplecov"; SimpleCov.start "rails"` at the top of your test helper, run the
  suite (`bin/rails test` or `bundle exec rspec`), then open `coverage/index.html`.
