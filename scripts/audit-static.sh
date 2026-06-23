#!/usr/bin/env bash
# Rails Health Audit — Phase 1 static scan.
# Usage: bash audit-static.sh /path/to/rails/project
# Orchestrates the canonical Ruby/Rails static-analysis tools, ranks findings
# most-severe-first, and writes <project>/tmp/health-audit/static-scan-report.md.
set -uo pipefail

PROJECT="${1:-$PWD}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd)" || { echo "No such directory: ${1:-}"; exit 1; }

if [[ ! -f "$PROJECT/Gemfile" || ! -f "$PROJECT/config/application.rb" ]]; then
  echo "Not a Rails project (need Gemfile + config/application.rb): $PROJECT"
  exit 1
fi

TS="$(date '+%Y%m%d-%H%M%S')"          # timestamp for this run's filenames
STAMP="$(date '+%Y-%m-%d %H:%M')"      # human-readable, shown inside the report
OUT="$PROJECT/tmp/health-audit"
RAW="$OUT/raw-result-$TS"             # per-run raw folder, never overwrites old runs
mkdir -p "$RAW"
REPORT="$OUT/static-scan-report-$TS.md"
RAW_REL="$(basename "$RAW")"          # relative name for links inside the report

echo "Rails Health Audit → $PROJECT"
echo "Report → $REPORT"
echo

# Run a tool by its installed binary, else via `gem exec` (no permanent install).
# usage: run_tool <gem_name> <binary> <logfile> [args...]
run_tool() {
  local gem="$1" bin="$2" log="$3"; shift 3
  if command -v "$bin" >/dev/null 2>&1; then
    ( cd "$PROJECT" && "$bin" "$@" ) >"$log" 2>&1
  else
    ( cd "$PROJECT" && gem exec -g "$gem" "$bin" "$@" ) >"$log" 2>&1
  fi
}

# Extract first integer matching a pattern from a log; default "?".
num() { grep -ioE "$1" "$2" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true; }

SRC_DIRS=()
[[ -d "$PROJECT/app" ]] && SRC_DIRS+=("app")
[[ -d "$PROJECT/lib" ]] && SRC_DIRS+=("lib")

# ---------------------------------------------------------------------------
# 1. SECURITY
# ---------------------------------------------------------------------------
echo "[1/7] Security — brakeman, bundler-audit"
run_tool brakeman brakeman "$RAW/brakeman.txt" -q --no-pager --no-exit-on-warn -f text .
BRAKEMAN=$(grep -E 'Security Warnings:' "$RAW/brakeman.txt" | grep -oE '[0-9]+' | head -1)
BRAKEMAN="${BRAKEMAN:-?}"
echo "  brakeman: ${BRAKEMAN} security warning(s)"

run_tool bundler-audit bundle-audit "$RAW/bundler-audit.txt" check --update
AUDIT=$(grep -c '^Name:' "$RAW/bundler-audit.txt" 2>/dev/null); AUDIT="${AUDIT:-?}"
echo "  bundler-audit: ${AUDIT} vulnerable gem advisory(ies)"

# ---------------------------------------------------------------------------
# 1b. LICENSING / COMPLIANCE
# ---------------------------------------------------------------------------
echo "[2/7] Compliance — license_finder"
run_tool license_finder license_finder "$RAW/license_finder.txt" action_items
if grep -qiE 'SolveFailure|Could not find|Could not resolve|Bundler::|LoadError|command not found|no such file' "$RAW/license_finder.txt" 2>/dev/null; then
  LICENSE="⚠️ skipped (couldn't resolve gems — needs a working \`bundle install\`)"
elif grep -qiE 'All dependencies.*approved' "$RAW/license_finder.txt" 2>/dev/null; then
  LICENSE=0
else
  LICENSE=$(grep -ciE '^[a-z0-9_.-]+, ' "$RAW/license_finder.txt" 2>/dev/null)
  LICENSE="${LICENSE:-?}"
fi
case "$LICENSE" in
  ⚠️*) echo "  license_finder: ${LICENSE}" ;;
  *)   echo "  license_finder: ${LICENSE} dependency(ies) needing license approval" ;;
esac

# ---------------------------------------------------------------------------
# 4. MAINTAINABILITY
# ---------------------------------------------------------------------------
echo "[3/7] Maintainability — rubycritic (reek+flay+flog), rubocop, erb_lint"
run_tool rubycritic rubycritic "$RAW/rubycritic.txt" --no-browser -f console -p "$RAW/rubycritic" "${SRC_DIRS[@]}"
RC_SCORE=$(grep -ioE 'score[: ]+[0-9]+(\.[0-9]+)?' "$RAW/rubycritic.txt" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
RC_SMELLS=$(grep -E 'Smells:' "$RAW/rubycritic.txt" | awk '{s+=$2} END{print s+0}')
RC_SMELLS="${RC_SMELLS:-?}"
echo "  rubycritic: score ${RC_SCORE:-?}, ${RC_SMELLS} smell(s)"

# --force-default-config so a project's stale .rubocop.yml can't abort the run.
run_tool rubocop rubocop "$RAW/rubocop.txt" --no-server --force-default-config --format simple "${SRC_DIRS[@]}"
if grep -q 'no offenses detected' "$RAW/rubocop.txt" 2>/dev/null; then
  RUBOCOP=0
else
  RUBOCOP=$(num '[0-9]+ offenses? detected' "$RAW/rubocop.txt"); RUBOCOP="${RUBOCOP:-?}"
fi
echo "  rubocop: ${RUBOCOP} offense(s)"

# erb_lint checks ERB view template style (what rubocop does not cover).
run_tool erb_lint erb_lint "$RAW/erb_lint.txt" --lint-all
if grep -qiE 'No errors were found' "$RAW/erb_lint.txt" 2>/dev/null; then
  ERBLINT=0
else
  ERBLINT=$(num '[0-9]+ error' "$RAW/erb_lint.txt"); ERBLINT="${ERBLINT:-?}"
fi
echo "  erb_lint: ${ERBLINT} ERB template offense(s)"

# ---------------------------------------------------------------------------
# 3. PERFORMANCE (static portion)
# ---------------------------------------------------------------------------
echo "[4/7] Performance (static) — fasterer"
run_tool fasterer fasterer "$RAW/fasterer.txt"
FASTERER=$(grep -cE '\.rb:[0-9]+' "$RAW/fasterer.txt" 2>/dev/null); FASTERER="${FASTERER:-?}"
echo "  fasterer: ${FASTERER} speed suggestion(s)"

# ---------------------------------------------------------------------------
# 4b. RAILS CONVENTIONS
# ---------------------------------------------------------------------------
echo "[5/7] Rails conventions — rails_best_practices"
run_tool rails_best_practices rails_best_practices "$RAW/rails_best_practices.txt" .
RBP=$(num 'found [0-9]+ warning' "$RAW/rails_best_practices.txt"); RBP="${RBP:-?}"
echo "  rails_best_practices: ${RBP} warning(s)"

# ---------------------------------------------------------------------------
# 5. TECH DEBT FRESHNESS
# ---------------------------------------------------------------------------
echo "[6/7] Tech debt — bundle outdated"
( cd "$PROJECT" && bundle outdated --parseable ) >"$RAW/outdated.txt" 2>&1
if grep -qiE 'your Ruby version|your Gemfile specified|Could not find|Bundler::' "$RAW/outdated.txt" 2>/dev/null; then
  OUTDATED="⚠️ skipped (Ruby/bundle mismatch — run with the project's own Ruby)"
else
  OUTDATED=$(grep -cE '\(newest' "$RAW/outdated.txt" 2>/dev/null)
  [[ "${OUTDATED:-0}" == "0" ]] && OUTDATED=$(grep -cE '^[a-z0-9_.-]+ \(' "$RAW/outdated.txt" 2>/dev/null)
  OUTDATED="${OUTDATED:-?}"
fi
echo "  bundle outdated: ${OUTDATED} gem(s) behind"

echo "[7/7] Writing report"

# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------
{
  echo "# Rails Health Audit — $(basename "$PROJECT")"
  echo
  echo "_Generated $STAMP. Phase 1 (static scan). Full raw tool output is in \`$RAW_REL/\`._"
  echo
  echo "## 1. Overview (every check, most severe first)"
  echo
  echo "| Priority | Category | Tool | Finding | Raw output |"
  echo "|----------|----------|------|---------|------------|"
  echo "| 🔴 1 | Security | brakeman | ${BRAKEMAN} warning(s) | \`$RAW_REL/brakeman.txt\` |"
  echo "| 🔴 1 | Security | bundler-audit | ${AUDIT} vulnerable advisory(ies) | \`$RAW_REL/bundler-audit.txt\` |"
  echo "| 🔴 1 | Compliance | license_finder | ${LICENSE} | \`$RAW_REL/license_finder.txt\` |"
  echo "| 🟡 3 | Performance | fasterer | ${FASTERER} speed suggestion(s) | \`$RAW_REL/fasterer.txt\` |"
  echo "| 🟡 4 | Maintainability | rubycritic | score ${RC_SCORE:-?}, ${RC_SMELLS:-?} smell(s) | \`$RAW_REL/rubycritic.txt\` |"
  echo "| 🟡 4 | Rails conventions | rails_best_practices | ${RBP} warning(s) | \`$RAW_REL/rails_best_practices.txt\` |"
  echo "| ⚪ 4 | Maintainability | rubocop | ${RUBOCOP} offense(s) | \`$RAW_REL/rubocop.txt\` |"
  echo "| ⚪ 4 | Maintainability | erb_lint | ${ERBLINT} ERB offense(s) | \`$RAW_REL/erb_lint.txt\` |"
  echo "| ⚪ 5 | Tech debt | bundle outdated | ${OUTDATED} | \`$RAW_REL/outdated.txt\` |"
  echo
  echo "Legend — 🔴 must fix (security / data) · 🟡 should fix (correctness / maintainability) · ⚪ nice to have (style / freshness)."
  echo
  echo "> **A ⚠️ skipped check is NOT a pass.** It means the tool could not run in this"
  echo "> environment, not that there is nothing wrong. license_finder needs a real"
  echo "> \`bundle install\`; bundle outdated needs the project's own Ruby (this run used a"
  echo "> different Ruby than the project pins). Re-run both in the project's environment"
  echo "> to get a real result."
  echo
  echo "## 2. Action plan"
  echo
  echo "_Severity first; cut noise with confidence/criticality (see note); call out any"
  echo "single root-cause fix. Format: [Category] problem (tool, file:line) → fix → effort (S/M/L)._"
  echo
  echo "1. [Security] ..."
  echo "2. [Security] ..."
  echo "3. [Maintainability] ..."
  echo
  echo "> **\"Cut noise with confidence/criticality\" means:** static tools over-report."
  echo "> brakeman tags each warning High / Medium / Weak confidence — fix the **High**"
  echo "> ones first, Weak ones are often false positives. bundler-audit tags each advisory"
  echo "> Critical / High / Medium — triage **Critical/High**, don't treat all 100+ as equal."
  echo "> So a raw count (e.g. \"137 advisories\") is a starting point, not 137 separate jobs."
  echo
  echo "## 3. Phase 2 — runtime checks (follow-up, need app + DB)"
  echo
  echo "These can't be answered by reading code; run them in the project (see audit-dynamic.sh):"
  echo
  echo "- **Data correctness** — \`active_record_doctor\` (missing FKs, NOT NULL, unique indexes, model/DB mismatch)"
  echo "- **Missing indexes** — \`lol_dba\` (\`db:find_indexes\`)"
  echo "- **N+1 queries** — \`bullet\` (dev/test) or \`prosopite\`; exercise app / run tests"
  echo "- **Test coverage** — \`simplecov\` → run the suite, read \`coverage/index.html\`"
} > "$REPORT"

echo
echo "Done. Report → $REPORT"
