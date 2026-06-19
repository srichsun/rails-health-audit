# rails-health-audit

A repeatable way to assess the health of an existing Rails codebase and turn the
result into a **prioritized action plan** — "find problem _X_ with tool _Y_, fix it
with method _Z_", ordered most-severe-first.

It is packaged as a [Claude Code](https://claude.com/claude-code) skill, but the core
is a plain shell script you can run on its own.

---

## Why this exists

Mature Rails systems accumulate debt: security holes, missing database constraints,
N+1 queries, duplicated code, and gems that are years behind. The Ruby ecosystem
already has excellent tools for each of these (brakeman, bundler-audit, rubocop,
rubycritic, …). What it lacks is the **judgment layer** on top:

- Which of the 9,000 findings actually matter?
- What do I fix _first_?
- Can I run the same assessment on the next project without re-deciding everything?

`rails-health-audit` is that layer. It is **not** another linter — it orchestrates the
canonical tools, ranks their output by **business impact**, and produces a plan a team
can act on.

---

## How it works

### The severity model

Findings are ranked by what they threaten, **not** by how many there are. One SQL
injection outranks ten thousand style offenses.

| Rank | Category | What it threatens | Tools (_Y_) | Typical fix (_Z_) |
|------|----------|-------------------|-------------|-------------------|
| 1 | Security | Breach, data leak | `brakeman`, `bundler-audit` | Patch, upgrade, sanitize |
| 2 | Data correctness | Bad / corrupt data | `active_record_doctor` (runtime) | Add FK / NOT NULL / unique index |
| 3 | Performance | Slowness, outages under load | `fasterer` (static); `bullet` / `prosopite`, `lol_dba` (runtime) | Eager load, add index, cache |
| 4 | Maintainability | Slow, risky changes | `rubycritic` (reek + flay + flog), `rubocop`, `rails_best_practices` | Extract service / concern, split methods |
| 5 | Tech-debt freshness | Vulnerability + drift accumulation | `bundle outdated`, `bundler-audit` | Scheduled gem upgrades |
| 6 | Dead code & coverage | Hidden risk, fear of change | `simplecov` (runtime) | Delete dead code, add tests |

### Two phases

**Phase 1 — static scan** (what the script automates): runs the tools that need only
source + `Gemfile.lock`. No app boot, no database, nothing installed permanently —
tools run via the installed binary, falling back to `gem exec` (Ruby 3.2+).

**Phase 2 — runtime checks** (documented in the report): the three checks that need the
app to boot against a database — data correctness (`active_record_doctor`), N+1
(`bullet`), and coverage (`simplecov`). These are listed as follow-ups rather than
auto-run, because they require temporarily adding gems to the target project.

### How it differs from CI and from rubycritic

- **vs. CI**: CI gates the _diff_ on every push — it stops _new_ problems. This audits
  the _whole existing codebase_, periodically, to surface the _accumulated_ backlog and
  rank it. They are complementary: audit finds the debt, then you wire the relevant
  checks into CI so it cannot come back.
- **vs. rubycritic / rails_code_auditor**: those run tools and report metrics. This adds
  the severity ranking, the runtime phase those static bundles skip, and the step that
  turns raw output into a prioritized plan.

---

## Install

As a Claude Code skill:

```sh
git clone https://github.com/<you>/rails-health-audit ~/.claude/skills/rails-health-audit
```

Claude Code picks it up automatically. You can then ask Claude to "audit this Rails
project's health", or run the script directly (below).

Standalone (no Claude Code needed):

```sh
git clone https://github.com/<you>/rails-health-audit
```

Requirements: Ruby 3.2+ (for `gem exec`). The analysis tools are fetched on demand.

---

## Usage

```sh
bash scripts/audit.sh /path/to/rails/project
```

This writes a ranked report to `<project>/tmp/health-audit/REPORT.md` and the full,
unprocessed tool output to `<project>/tmp/health-audit/raw/`. The summary is printed to
the terminal.

Then triage: read the raw logs, pick the top handful of highest-impact items, and fill
in the report's **Action plan** section — one line each: `[Category] problem → fix →
effort`. (Inside Claude Code this triage step can be done for you from the raw logs.)

---

## Try it on the bundled example

The repo ships a tiny, **intentionally broken** Rails-shaped app so you can see the
audit light up without pointing it at your own code:

```sh
bash scripts/audit.sh examples/legacy_blog
cat examples/legacy_blog/tmp/health-audit/REPORT.md
```

See [`examples/legacy_blog/README.md`](examples/legacy_blog/README.md) for the list of
problems planted in it.

A real-world walkthrough (a legacy Rails 4.1 app) is in
[`docs/case-study-legacy-rails.md`](docs/case-study-legacy-rails.md).

---

## Limitations

- Phase 1 is static only. The runtime checks (rank 2, and the N+1 part of rank 3) are
  documented, not executed.
- `bundle outdated` needs the project's own Ruby; it is skipped with a note when the
  ambient Ruby does not match the project's pinned version.
- The audit assesses and plans. It never edits your code — that decision stays human.

## License

MIT — see [LICENSE](LICENSE).
