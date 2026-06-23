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
| 1 | Compliance | Legal/licensing risk | `license_finder` | Approve or replace the gem |
| 2 | Data correctness | Bad/corrupt data | `active_record_doctor` (runtime) | Add FK / NOT NULL / unique index |
| 3 | Performance | Slowness, outages under load | `fasterer` (static); `bullet`/`prosopite`, `lol_dba` (runtime) | Eager load, add index, cache |
| 4 | Maintainability | Slow, risky changes | `rubycritic` (=reek+flay+flog), `rubocop`, `rails_best_practices`, `erb_lint` | Extract service/concern, split methods |
| 5 | Tech debt freshness | Vuln + drift accumulation | `bundle outdated`, `bundler-audit` | Scheduled gem upgrades |
| 6 | Dead code & coverage | Hidden risk, fear of change | `simplecov` (runtime) | Delete dead code, add tests |

All tools above are the recognized/canonical ones in the Ruby ecosystem (brakeman,
bundler-audit, rubocop, rubycritic, rails_best_practices, bullet, simplecov,
active_record_doctor). This skill is the **judgment layer** on top — severity ranking by
business impact + runtime checks the static bundles skip + an action plan — not a
reinvention of those tools.

## How to run

> **The audit is ALWAYS two steps: run the script, then fill the Action plan.**
> The script alone only produces a blank template. When this skill runs, you MUST
> do both steps before reporting back — a scan without a filled Action plan is
> considered incomplete. The plan is the whole point of this skill.

### Phase 1 — static scan (works on any project, no app changes)

```
bash ~/.claude/skills/rails-health-audit/scripts/audit-static.sh /path/to/rails/project
```

This runs the tools that need only source + `Gemfile.lock`:
**security (brakeman, bundler-audit), maintainability (reek/flog/flay), tech-debt
freshness (bundle outdated)**. It writes a ranked report to
`<project>/tmp/health-audit/static-scan-report.md` and prints a summary.

Tools are invoked via the installed binary, falling back to `gem exec` (Ruby 3.2+)
so nothing is permanently added to the target project.

**Then immediately do Phase 1b below — don't stop at the raw numbers.**

### Phase 2 — runtime scan (needs the app booting + a DB)

These need to load the app against its database. `scripts/audit-dynamic.sh <project>` automates
the first two through a **temporary** bundle (the project's `Gemfile` is never touched):

- **Data correctness** — `active_record_doctor`: missing FKs, NOT NULL, unique indexes,
  model/DB mismatch.
- **Missing indexes** — `lol_dba` (`db:find_indexes`).

Only run `audit-dynamic.sh` when the project's DB is set up and migrated; it writes `dynamic-scan-report.md`.
The N+1 (`bullet`/`prosopite`) and coverage (`simplecov`) checks need the app *exercised*
(requests / test suite), so leave them as documented follow-ups.

### Phase 1b — fill the Action plan (REQUIRED, not optional)

`audit-static.sh` only writes an empty Action plan template; the prioritization is the judgment
this skill exists for. **As soon as the scan finishes, read the raw logs in
`tmp/health-audit/raw/` and replace the empty `## Action plan` section of
`static-scan-report.md` with a real, ranked plan** — then report the filled plan to the
user. Never hand back the blank template. How to prioritize:

1. **Business impact over volume** — order security → data correctness → performance →
   maintainability → style. A SQL injection outranks 9,000 style offenses.
2. **Cut noise with confidence/criticality** — e.g. fix brakeman's *High*-confidence
   warnings first; triage bundler-audit's *Critical*/*High*, not every advisory.
3. **Find the one fix that clears a column** — many advisories often collapse into a
   single root-cause move (e.g. upgrading an EOL Rails). Call it out explicitly.
4. **Sequence by risk** — risky changes (a major upgrade) go behind a safety net (green
   tests in CI) first.

Write each item as **[Category] problem (found by tool) → concrete fix → rough effort
(S/M/L)**. Keep it to the top ~6–10 so it is actionable, not a dump. See
`examples/legacy_blog/sample-static-scan-report.md` for a worked example.

## Notes

- If the target is not a Rails app (no `Gemfile` + `config/application.rb`), say so and stop.
- Never auto-apply fixes. This skill assesses and plans; the human decides what to change.
- Re-running on a new project is the whole point — the method is the asset, not any one report.
