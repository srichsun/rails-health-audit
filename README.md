# 🩺 rails-health-audit

**English** | [繁體中文](README.zh-TW.md)

A repeatable way to assess the health of an existing Rails codebase and turn the
result into a **prioritized action plan** — "find problem _X_ with tool _Y_, fix it
with method _Z_", ordered most-severe-first.

It is packaged as a [Claude Code](https://claude.com/claude-code) skill, but the core
is a plain shell script you can run on its own.

---

## 🤔 Why this exists

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

## 🎯 When to use it — and when not to

**A good fit when:**
- You're inheriting or onboarding a codebase you didn't write and need a map of its weak
  spots fast.
- The project is legacy with no CI, or only partial CI.
- You're planning a refactor / cleanup and need a prioritized backlog, not a pass/fail gate.
- You're assessing a system one-off — due diligence, or a team taking over someone else's app.
- You want the runtime data-correctness / N+1 checks that most CI pipelines don't run.

**Not the right tool when:**
- The project already has mature CI running these checks on every PR — re-running the
  static ones adds little.
- You want a merge gate: that's CI's job (gate the diff). This produces a report to
  prioritize from, not a build pass/fail.
- You expect it to replace CI. It's a periodic assessment, not continuous enforcement —
  the two are complementary: this finds the backlog, CI keeps it from coming back.

---

## ⚙️ How it works

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

**Pass 2 — run the app.** Three things can't be answered by reading code; the app has to
run against a real, migrated database:

- Is the data safe? — missing foreign keys, indexes, `NOT NULL`, unique constraints
  (`active_record_doctor`, `lol_dba`)
- Are there slow N+1 queries? (`bullet` / `prosopite`)
- How much of the code do the tests actually cover? (`simplecov`)

`scripts/audit-dynamic.sh` automates the first group: it boots the app and runs the
data-correctness and indexing detectors through a **temporary** bundle, so the project's
own `Gemfile` / `Gemfile.lock` are never touched. The N+1 and coverage checks still need
the app *exercised* (requests, or the test suite) — they only surface on code paths that
actually execute — so they stay documented follow-ups.

In one line: **Pass 1 reads the code (always safe to run); Pass 2 boots the app to catch
what reading can't (needs the DB set up).**

### What each tool checks

| Category | Tool | What it checks |
|----------|------|----------------|
| Security | [**brakeman**](https://github.com/presidentbeef/brakeman) | Reads your Rails code (without running it) for security holes — SQL injection, XSS, unsafe redirects |
| Security | [**bundler-audit**](https://github.com/rubysec/bundler-audit) | Your locked gem versions against a database of known security advisories (CVEs) |
| Compliance | [**license_finder**](https://github.com/pivotal/LicenseFinder) | The license of every gem; flags any the project hasn't approved |
| Data correctness | [**active_record_doctor**](https://github.com/gregnavis/active_record_doctor) _(Pass 2)_ | Whether the database actually enforces what your models assume — missing foreign keys, indexes, `NOT NULL`, unique constraints |
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

> Setting up license governance? See a commented sample config at
> [`docs/license_finder.sample.yml`](docs/license_finder.sample.yml).

### How it differs from CI and from rubycritic

- **vs. CI**: CI gates the _diff_ on every push — it stops _new_ problems. This audits
  the _whole existing codebase_, periodically, to surface the _accumulated_ backlog and
  rank it. They are complementary: audit finds the debt, then you wire the relevant
  checks into CI so it cannot come back.
- **vs. rubycritic / rails_code_auditor**: those run tools and report metrics. This adds
  the severity ranking, the runtime phase those static bundles skip, and the step that
  turns raw output into a prioritized plan.

---

## 🧭 How it compares

There are plenty of code-health tools. This one isn't trying to beat them — it fills a
specific niche. What's distinctive is the **combination**: Rails-aware checks **+**
runtime data-correctness **+** zero footprint — not any single feature.

| Tool | Rails-aware | Runtime data-correctness¹ | Runs where |
|------|:-----------:|:-------------------------:|------------|
| **rails-health-audit** (this) | ✅ | ✅ `active_record_doctor`, `lol_dba` | Local / Claude Code — nothing added to the project |
| rails_code_auditor | ✅ | ❌ static only | Gem added to the project |
| rails_code_health · rails-audit | ✅ | ❌ static only | Gem added to the project |
| CodeScene | ❌ language-agnostic² | ❌ | Commercial SaaS |
| DeepSource | ❌ Ruby analyzer, not Rails-framework | ❌ | SaaS |
| SonarQube | ❌ multi-language | ❌ | SaaS / self-hosted |
| Tech Debt Reviewer (Claude skill) | ❌ language-agnostic | ❌ | Claude Code |

¹ Booting the app to check that the database enforces what the models assume — missing
foreign keys, `NOT NULL`, unique indexes. ² CodeScene, DeepSource and SonarQube all
*support* Ruby, but analyze it generically; they don't reason about Rails / ActiveRecord
conventions.

It doesn't replace any of these — a team already on CodeScene or with mature CI is well
covered. The point is a lightweight, Rails-aware, zero-footprint assessment you can run on
a codebase you've just inherited.

**Sources:** [Best Code Health Tools in 2026 (repowise)](https://www.repowise.dev/blog/comparisons/best-code-health-tools-2026)
· [10 Best Code Audit Tools in 2026 (Panto)](https://www.getpanto.ai/blog/best-code-audit-tools)
· [Top Technical Debt Tools 2026 (CodeAnt)](https://www.codeant.ai/blogs/tools-measure-technical-debt)
· [CodeScene language support](https://docs.enterprise.codescene.io/latest/usage/language-support.html)
· [DeepSource Ruby (GA)](https://deepsource.com/blog/ruby-general-availability-release/)
· [SonarQube Ruby](https://docs.sonarsource.com/sonarqube-server/latest/analyzing-source-code/languages/ruby/)

---

## 📦 Install

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
> have to `gem install` all these tools up front, and nothing is added to your system gems
> or to the project's `Gemfile` — the audit stays self-contained and leaves no trace.
> `gem exec` ships with the RubyGems bundled in Ruby 3.2+, which is why that's the floor.

---

## 🚀 Usage

**With Claude Code (easiest).** Just ask in plain language — Claude picks up the skill,
runs the scan, and does the triage for you:

> "Audit this Rails project's health"

Or invoke it explicitly as a slash command:

```
/rails-health-audit /path/to/rails/project
```

**Standalone — one command.** Run it directly (no Claude Code needed):

```sh
bash scripts/audit.sh /path/to/rails/project
```

`audit.sh` runs the static scan, then best-effort runs the runtime scan — only if the app
boots and its database is migrated; otherwise the runtime phase is skipped automatically
and the report explains how to enable it. (Internally it calls `audit-static.sh` and
`audit-dynamic.sh`, but the command you run is `audit.sh`.)

Either way, it writes a single ranked report to
`<project>/tmp/health-audit/report-<timestamp>/health-audit-report.md` and the full,
unprocessed tool output to that run's `raw_original_result/`. The summary is printed to
the terminal.

Then triage: read the raw logs, pick the top handful of highest-impact items, and fill
in the report's **Action plan** section — one line each: `[Category] problem → fix →
effort`. (Inside Claude Code this triage step can be done for you from the raw logs.)

To get the runtime (Pass 2) results folded in, make sure the project's database is set up
and migrated before you run `audit.sh`; on a project whose DB isn't ready, the runtime
phase is skipped and only the static results appear.

---

## 📁 Output

Everything lands under `<project>/tmp/health-audit/` (git-ignored — it's generated). The
scripts also print the report path to the terminal when they finish.

Each run gets its own timestamped `report-<timestamp>/` folder, so a new run never
overwrites an older one — keep them to diff before/after.

```
<project>/tmp/health-audit/
└── report-<timestamp>/                  # one folder per run
    ├── health-audit-report.md           # working source: Overview + Action plan + Still to run
    ├── health-audit-report.pdf           # the shareable deliverable (from export.sh)
    └── raw_original_result/             # full, unprocessed output from every tool
        ├── brakeman.txt
        ├── bundler-audit.txt
        ├── license_finder.txt
        ├── rubocop.txt
        ├── erb_lint.txt
        ├── rubycritic.txt
        ├── fasterer.txt
        ├── rails_best_practices.txt
        ├── outdated.txt
        ├── pass2_ar_doctor.txt          # runtime (Pass 2) — only when the app + DB ran
        └── pass2_lol_dba.txt            # runtime (Pass 2) — only when the app + DB ran
```

The `health-audit-report.md` is the one you read and act on. It has three sections —
"## 1. Overview", "## 2. Action plan", and "## 3. Still to run" — the runtime results
(`active_record_doctor`, `lol_dba`) fold straight into the Overview table and Action plan,
and section 3 just lists what's left to run manually. Each Action plan item cites
the `file:line` and the `raw_original_result/…txt` it came from, so findings are traceable.

Want a shareable copy? `bash scripts/export.sh <project>` renders `health-audit-report.md`
to `health-audit-report.pdf` (the `.md` stays the editable source of truth).

---

## 🧪 Try it on the bundled example

The repo ships a real, **intentionally broken** Rails 8 app (`example-unhealthy-project`)
that actually `bundle install`s — so every tool (including license_finder and bundle
outdated) produces a real finding, not a "skipped". Point the audit at it:

```sh
bash scripts/audit.sh examples/example-unhealthy-project
open examples/example-unhealthy-project/tmp/health-audit/report-*/health-audit-report.pdf
```

Want to see what you get before running anything? A committed sample is in the repo —
**[📄 example health-audit-report.pdf](examples/example-unhealthy-project/tmp/health-audit/report-20260623-154905/health-audit-report.pdf)**
(Overview + a fully filled Action plan, exported from
[the markdown source](examples/example-unhealthy-project/tmp/health-audit/report-20260623-154905/health-audit-report.md)).
See [`examples/example-unhealthy-project/README.md`](examples/example-unhealthy-project/README.md)
for the list of problems planted in it.

A real-world walkthrough (a legacy Rails 4.1 app) is in
[`docs/case-study-legacy-rails.md`](docs/case-study-legacy-rails.md).

---

## ⚠️ Limitations

- `audit-dynamic.sh` automates the data-correctness and indexing checks, but the N+1 and coverage
  checks still need the app *exercised* (requests / the test suite), so those stay manual.
- `bundle outdated` needs the project's own Ruby; it is skipped with a note when the
  ambient Ruby does not match the project's pinned version.
- The audit assesses and plans. It never edits your code — that decision stays human.

## 📄 License

MIT — see [LICENSE](LICENSE).
