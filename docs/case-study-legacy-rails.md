# Case study: auditing a legacy Rails 4.1 app

**English** | [繁體中文](case-study-legacy-rails.zh-TW.md)

I pointed `rails-health-audit` at a real legacy codebase — a Rails **4.1** / Ruby
**2.3.5** application, ~24k lines across 433 files, 101 gems. Rails 4.1 has been
end-of-life for years, so I expected it to be unhealthy. The interesting part was never
"is it bad" — it was **what do you fix first** when the scan comes back red across the
board.

## The raw numbers

One command, a few minutes:

```sh
bash scripts/audit-static.sh /path/to/app
```

| Rank | Category | Tool | Finding |
|------|----------|------|---------|
| 1 | Security | brakeman | **84** warnings (46 SQL injection, 9 command injection, 9 CSRF, …) |
| 1 | Security | bundler-audit | **170** vulnerable-gem advisories (11 Critical, 65 High, 61 Medium) |
| 3 | Performance | fasterer | 104 suggestions |
| 4 | Maintainability | rubycritic | score **72.5** / 100, **4,562** smells |
| 4 | Maintainability | rubocop | **9,321** offenses |
| 4 | Rails conventions | rails_best_practices | **449** warnings |
| 5 | Tech debt | bundle outdated | skipped (pinned to Ruby 2.3.5) |

Eleven thousand findings. If you start at the top of that list and work down, you will
spend a month on RuboCop and never touch the SQL injection. So the value of the tool is
not the numbers — it is the ordering that comes next.

## How the priority is decided

Four rules, applied in order. None of them is "biggest number first."

**1. Business impact beats volume.** A SQL injection can put the company in the news;
9,321 style offenses cannot. The fixed order is _security → data correctness →
performance → maintainability → style_.

**2. Use confidence / criticality to cut the noise.** brakeman reported 84, but only
**13** are High-confidence — 45 are "Weak" and mostly false positives on old code. Fix
the 13 first. Same on the dependency side: triage the **11 Critical + 65 High**, not all
170 at once.

**3. Find the one fix that clears a whole column.** The 170 advisories are not 170
jobs — they cluster on a handful of ancient gems: `nokogiri` (37), `rack` (36), Rails
core (~24), `puma` (12). Upgrading Rails off 4.1 onto a supported line, then
`bundle update`, dissolves the bulk of them — including most of the Criticals — in a
single, planned move. That is the highest-leverage action in the whole report.

**4. Risk and safety nets decide sequencing.** A major framework upgrade is dangerous
without tests to catch regressions. This app happened to have ~293 specs, so step zero
is: get them green and into CI _first_, then do the risky upgrade behind that safety net.

## The resulting plan

- **Step 0 — Safety net.** Run the existing specs, get them green, wire them into CI.
  Nothing risky happens before this.
- **Step 1 — The 13 High-confidence security holes.** Parameterize the interpolated
  SQL, lock down the command-injection sinks. Small, low-risk, high-value edits.
- **Step 2 — Upgrade Rails off 4.1 + `bundle update`.** The single highest-leverage move;
  clears most of the 170 advisories and the Criticals. Staged, behind the Step 0 net.
- **Step 3 — Remaining vulnerable gems** not covered by the Rails bump (nokogiri, puma,
  devise, …): bump individually.
- **Step 4 — Maintainability, selectively.** `rubocop -a` clears thousands of trivial
  offenses for almost free; then refactor only the worst files RubyCritic flagged, and
  the 21 `rescue Exception` blocks (they swallow real bugs).
- **Step 5 — Conventions & micro-perf, opportunistically.** Fix the fat controllers and
  fasterer hits when you are already in that code — not as a dedicated sprint.
- **Step 6 — Lock it in.** Add brakeman + bundler-audit + rubocop to CI with a baseline
  so the cleanup cannot quietly regress.

## The takeaway

A static scan is a diagnosis, not a cure. The skill that matters in a legacy codebase is
not running the tools — anyone can do that — it is reading eleven thousand findings and
saying, with reasons, "do these six things, in this order." The biggest win here was a
single root-cause move (the Rails upgrade) that a count-sorted list would have buried on
page forty.
