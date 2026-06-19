<!-- A committed snapshot of the report for examples/legacy_blog.
     The summary/findings are produced by: bash scripts/audit.sh examples/legacy_blog
     The Action plan at the bottom is the triage step — written by reading the raw logs
     (by you, or by Claude when the skill runs inside Claude Code). -->

# Rails Health Audit — legacy_blog

_Generated 2026-06-19 15:13. Phase 1 static scan. Raw output in `tmp/health-audit/raw/`._

## Summary (most severe first)

| Rank | Category | Tool | Finding |
|------|----------|------|---------|
| 1 | Security | brakeman | 8 warning(s) |
| 1 | Security | bundler-audit | 129 vulnerable advisory(ies) |
| 1 | Compliance | license_finder | 2 dep(s) needing approval |
| 3 | Performance | fasterer | 0 speed suggestion(s) |
| 4 | Maintainability | rubycritic | score 89.01, 22 smell(s) |
| 4 | Maintainability | rubocop | 20 offense(s) |
| 4 | Maintainability | erb_lint | 11 ERB offense(s) |
| 4 | Rails conventions | rails_best_practices | 13 warning(s) |
| 5 | Tech debt | bundle outdated | skipped (Ruby/bundle mismatch — run with project's Ruby) gem(s) behind |

> Ranks 2 (data correctness) and the N+1 part of rank 3 need the app to boot —
> see Phase 2 below.

## Phase 2 — runtime checks (follow-up, need app + DB)

Add temporarily to `Gemfile` (`:development`/`:test`) and run in the project:

- **Data correctness** — `active_record_doctor` → `bundle exec rake active_record_doctor`
  (missing FKs, NOT NULL, unique indexes, model/DB mismatch)
- **Missing indexes** — `lol_dba` → `bundle exec rake db:find_indexes`
- **N+1 queries** — `bullet` (dev/test) or `prosopite`; exercise app / run tests
- **Test coverage** — `simplecov` → run the suite, read `coverage/index.html`

## Action plan

_Severity first, with the one root-cause move called out. Format: [Category] problem → fix → effort._

1. [Security] SQL injection ×2 + command injection in `posts_controller.rb` (brakeman, High)
   → parameterize the `where`, replace `system("convert #{...}")` with a safe image API → S, do first.
2. [Security] CSRF protection disabled → add `protect_from_forgery with: :exception` to
   `ApplicationController` → S.
3. [Security] XSS in `views/posts/index.html.erb` → drop `html_safe` on `params[:q]`,
   let Rails escape it → S.
4. [Security + Tech debt] Rails 4.1.16 is EOL and drives most of the 129 advisories
   (8 Critical, 50 High, clustered on rails / rack / nokogiri) → upgrade Rails to a supported
   line, then `bundle update`. **Highest-leverage move — clears the bulk in one go.** → L,
   staged behind tests.
5. [Compliance] Review the 2 dependencies license_finder flagged → add a
   `.license_finder.yml` permitting the approved licenses → S.
6. [Maintainability] Delete the 5 unused methods, replace `rescue Exception`, extract the
   duplicated create/update logic; `rubocop -a` for the 20 style offenses; tidy ERB → M,
   opportunistic.

> A static scan is a diagnosis, not a cure. The value is this ordering — note that
> upgrading Rails (item 4) dissolves far more than fixing findings one by one would.
