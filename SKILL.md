---
name: rails-health-audit
description: Audit the health of any Rails codebase and produce a severity-ranked action plan. Use when asked to assess code quality, find tech debt, scan a Rails project for security/performance/maintainability issues, or plan a refactor/optimization. Runs static analysis tools, ranks findings most-severe-first, and emits a prioritized improvement plan.
---

# Rails Health Audit

A repeatable method for assessing an existing Rails codebase and turning the result
into a prioritized improvement plan — "find problem X with tool Y, fix it with method Z",
ordered most-severe-first.

The point is not to run every tool. It is to surface the issues that hurt **stability,
data correctness, and maintainability** first, then hand back a plan a team can act on.

## When to use

- "Is this codebase healthy? Where do I start?"
- Planning a refactor / optimization sprint on a legacy app.
- Onboarding to an unfamiliar Rails system and needing a map of its weak spots.
- Producing evidence of code quality for a review.

## Severity model

Findings are ranked by **business impact**, not by how easy they are to fix.

| Rank | Category | What it threatens | Tools (Y) | Typical fix (Z) |
|------|----------|-------------------|-----------|------------------|
| 1 | Security | Breach, data leak | `brakeman`, `bundler-audit` | Patch, upgrade, sanitize |
| 2 | Data correctness | Bad/corrupt data | `active_record_doctor` (runtime) | Add FK / NOT NULL / unique index |
| 3 | Performance | Slowness, outages under load | `fasterer` (static); `bullet`/`prosopite`, `lol_dba` (runtime) | Eager load, add index, cache |
| 4 | Maintainability | Slow, risky changes | `rubycritic` (=reek+flay+flog), `rubocop`, `rails_best_practices` | Extract service/concern, split methods |
| 5 | Tech debt freshness | Vuln + drift accumulation | `bundle outdated`, `bundler-audit` | Scheduled gem upgrades |
| 6 | Dead code & coverage | Hidden risk, fear of change | `simplecov` (runtime) | Delete dead code, add tests |

All tools above are the recognized/canonical ones in the Ruby ecosystem (brakeman,
bundler-audit, rubocop, rubycritic, rails_best_practices, bullet, simplecov,
active_record_doctor). This skill is the **judgment layer** on top — severity ranking by
business impact + runtime checks the static bundles skip + an action plan — not a
reinvention of those tools.

## How to run

### Phase 1 — static scan (works on any project, no app changes)

```
bash ~/.claude/skills/rails-health-audit/scripts/audit.sh /path/to/rails/project
```

This runs the tools that need only source + `Gemfile.lock`:
**security (brakeman, bundler-audit), maintainability (reek/flog/flay), tech-debt
freshness (bundle outdated)**. It writes a ranked report to
`<project>/tmp/health-audit/REPORT.md` and prints a summary.

Tools are invoked via the installed binary, falling back to `gem exec` (Ruby 3.2+)
so nothing is permanently added to the target project.

### Phase 2 — runtime scan (needs the app booting + a DB)

These three need to load the app, so they require temporarily adding gems to the
target project's `Gemfile` (`:development` group) and running there:

- **Data correctness** — `active_record_doctor`: add gem, run
  `bundle exec rake active_record_doctor`. Flags missing FKs, missing NOT NULL,
  missing unique indexes, model/DB mismatch.
- **Missing indexes** — `lol_dba`: `bundle exec rake db:find_indexes`.
- **N+1 queries** — `bullet` (in test/dev) or `prosopite`: enable, exercise the app
  or run the test suite, collect warnings.

Document each as a follow-up item in the report rather than auto-installing.

## Turning the scan into a plan

After the scan, write the action plan in `REPORT.md` in this shape, severity-first:

```
## Action plan (most severe first)
1. [Security] <N> brakeman warnings → review high-confidence ones, patch.
2. [Data] add FK on orders.user_id (active_record_doctor) → migration.
3. [Perf] N+1 on Order#line_items in checkout → includes(:line_items).
...
```

Each item = **problem (found by tool) → concrete fix → rough effort**. Keep it to the
top ~10 so it is actionable, not a dump.

## Notes

- If the target is not a Rails app (no `Gemfile` + `config/application.rb`), say so and stop.
- Never auto-apply fixes. This skill assesses and plans; the human decides what to change.
- Re-running on a new project is the whole point — the method is the asset, not any one report.
