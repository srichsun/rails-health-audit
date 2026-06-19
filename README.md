# rails-health-audit

**English** | [繁體中文](README.zh-TW.md)

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
| 1 | Compliance | Legal / licensing risk | `license_finder` | Approve or replace the gem |
| 2 | Data correctness | Bad / corrupt data | `active_record_doctor` (runtime) | Add FK / NOT NULL / unique index |
| 3 | Performance | Slowness, outages under load | `fasterer` (static); `bullet` / `prosopite`, `lol_dba` (runtime) | Eager load, add index, cache |
| 4 | Maintainability | Slow, risky changes | `rubycritic` (reek + flay + flog), `rubocop`, `rails_best_practices`, `erb_lint` | Extract service / concern, split methods |
| 5 | Tech-debt freshness | Vulnerability + drift accumulation | `bundle outdated`, `bundler-audit` | Scheduled gem upgrades |
| 6 | Dead code & coverage | Hidden risk, fear of change | `simplecov` (runtime) | Delete dead code, add tests |

### Two passes: a quick read, then a deeper look

**Pass 1 — read the code (the script does this for you, automatically).**
It only _reads_ your source files and your gem list. It never starts your app, never
touches your database, and installs nothing into your project. So it is safe to run on
any codebase at any time, and it is fast. This pass covers security, licensing,
maintainability, conventions, and tech debt. (Tools run from your installed binary, or
are fetched on the fly with `gem exec` if you don't have them — Ruby 3.2+.)

**Pass 2 — run the app (the script only _lists_ these; it does not run them).**
Three things simply cannot be answered by reading code — you have to actually run the
app against a real database:

- Is the data safe? — missing foreign keys / indexes (`active_record_doctor`)
- Are there slow N+1 queries? (`bullet`)
- How much of the code do the tests actually cover? (`simplecov`)

Running these means temporarily adding a gem or two and booting the app, so the audit
doesn't do it automatically — it writes them into the report as clear next steps.

In one line: **Pass 1 reads the code (automatic, safe, fast); Pass 2 runs the app to
catch what reading can't (a manual follow-up).**

### What each tool checks

| Category | Tool | What it checks |
|----------|------|----------------|
| Security | [**brakeman**](https://github.com/presidentbeef/brakeman) | Reads your Rails code (without running it) for security holes — SQL injection, XSS, unsafe redirects |
| Security | [**bundler-audit**](https://github.com/rubysec/bundler-audit) | Your locked gem versions against a database of known security advisories (CVEs) |
| Compliance | [**license_finder**](https://github.com/pivotal/LicenseFinder) | The license of every gem; flags any the project hasn't approved |
| Data correctness | [**active_record_doctor**](https://github.com/gregnavis/active_record_doctor) _(Pass 2)_ | DB vs. models — missing foreign keys, indexes, `NOT NULL`, unique constraints |
| Performance | [**fasterer**](https://github.com/DamirSvrtan/fasterer) | Slow Ruby idioms (quick static hints) |
| Performance | [**bullet**](https://github.com/flyerhzm/bullet) _(Pass 2)_ | N+1 queries while the app runs |
| Performance | [**prosopite**](https://github.com/charkost/prosopite) _(Pass 2)_ | N+1 queries — stricter than bullet |
| Performance | [**lol_dba**](https://github.com/plentz/lol_dba) _(Pass 2)_ | Lookup columns that have no database index |
| Maintainability | [**rubycritic**](https://github.com/whitesmith/rubycritic) | Overall quality score (A–F); runs the three below and combines them |
| Maintainability | ↳ [**reek**](https://github.com/troessner/reek) | Code smells — long methods, vague names, classes doing too much |
| Maintainability | ↳ [**flog**](https://github.com/seattlerb/flog) | How complex / hard-to-test each method is |
| Maintainability | ↳ [**flay**](https://github.com/seattlerb/flay) | Duplicated / copy-pasted code |
| Maintainability | [**rubocop**](https://github.com/rubocop/rubocop) | Ruby style & lint — the de-facto standard |
| Maintainability | [**rails_best_practices**](https://github.com/flyerhzm/rails_best_practices) | Rails-specific advice — fat controllers, logic that belongs in models, Law of Demeter |
| Maintainability | [**erb_lint**](https://github.com/Shopify/erb-lint) | ERB view templates — formatting consistency by default, plus unsafe-output (XSS) checks if enabled; rubocop can't see ERB |
| Tech debt | [**bundle outdated**](https://bundler.io/man/bundle-outdated.1.html) | Gems behind their latest release |
| Coverage | [**simplecov**](https://github.com/simplecov-ruby/simplecov) _(Pass 2)_ | How much of your code the test suite actually runs |

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
git clone https://github.com/srichsun/rails-health-audit ~/.claude/skills/rails-health-audit
```

Claude Code picks it up automatically. You can then ask Claude to "audit this Rails
project's health", or run the script directly (below).

Standalone (no Claude Code needed):

```sh
git clone https://github.com/srichsun/rails-health-audit
```

Requirements: Ruby 3.2+ (for `gem exec`). The analysis tools are fetched on demand.

> **Why `gem exec`?** It runs each tool without permanently installing it. So you don't
> have to `gem install` nine tools up front, and nothing is added to your system gems or
> to the project's `Gemfile` — the audit stays self-contained and leaves no trace.
> `gem exec` ships with the RubyGems bundled in Ruby 3.2+, which is why that's the floor.

---

## Usage

**With Claude Code (easiest).** Just ask in plain language — Claude picks up the skill,
runs the scan, and does the triage for you:

> "Audit this Rails project's health"

Or invoke it explicitly as a slash command:

```
/rails-health-audit /path/to/rails/project
```

**Standalone (no Claude Code).** Run the script directly:

```sh
bash scripts/audit.sh /path/to/rails/project
```

Either way, it writes a ranked report to `<project>/tmp/health-audit/REPORT.md` and the
full, unprocessed tool output to `<project>/tmp/health-audit/raw/`. The summary is
printed to the terminal.

Then triage: read the raw logs, pick the top handful of highest-impact items, and fill
in the report's **Action plan** section — one line each: `[Category] problem → fix →
effort`. (Inside Claude Code this triage step can be done for you from the raw logs.)

---

## Try it on the bundled example

The repo ships a tiny, **intentionally broken** Rails app so you can see the
audit light up without pointing it at your own code:

```sh
bash scripts/audit.sh examples/legacy_blog
cat examples/legacy_blog/tmp/health-audit/REPORT.md
```

See [`examples/legacy_blog/README.md`](examples/legacy_blog/README.md) for the list of
problems planted in it, or read the committed output snapshot at
[`examples/legacy_blog/SAMPLE_REPORT.md`](examples/legacy_blog/SAMPLE_REPORT.md) without
running anything.

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
