#!/usr/bin/env bash
# Rails Health Audit — Phase 1 static scan.
# Usage: bash audit.sh /path/to/rails/project
# Orchestrates the canonical Ruby/Rails static-analysis tools, ranks findings
# most-severe-first, and writes <project>/tmp/health-audit/REPORT.md.
set -uo pipefail

PROJECT="${1:-$PWD}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd)" || { echo "No such directory: ${1:-}"; exit 1; }

if [[ ! -f "$PROJECT/Gemfile" || ! -f "$PROJECT/config/application.rb" ]]; then
  echo "Not a Rails project (need Gemfile + config/application.rb): $PROJECT"
  exit 1
fi

OUT="$PROJECT/tmp/health-audit"
RAW="$OUT/raw"
mkdir -p "$RAW"
REPORT="$OUT/REPORT.md"
STAMP="$(date '+%Y-%m-%d %H:%M')"

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
    ( cd "$PROJECT" && gem exec "$gem" "$@" ) >"$log" 2>&1
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
echo "[1/6] Security — brakeman, bundler-audit"
run_tool brakeman brakeman "$RAW/brakeman.txt" -q --no-pager --no-exit-on-warn -f text .
BRAKEMAN=$(grep -E 'Security Warnings:' "$RAW/brakeman.txt" | grep -oE '[0-9]+' | head -1)
BRAKEMAN="${BRAKEMAN:-?}"
echo "  brakeman: ${BRAKEMAN} security warning(s)"

run_tool bundler-audit bundle-audit "$RAW/bundler-audit.txt" check --update
AUDIT=$(grep -c '^Name:' "$RAW/bundler-audit.txt" 2>/dev/null); AUDIT="${AUDIT:-?}"
echo "  bundler-audit: ${AUDIT} vulnerable gem advisory(ies)"

# ---------------------------------------------------------------------------
# 4. MAINTAINABILITY
# ---------------------------------------------------------------------------
echo "[2/6] Maintainability — rubycritic (reek+flay+flog), rubocop"
run_tool rubycritic rubycritic "$RAW/rubycritic.txt" --no-browser -f console -p "$RAW/rubycritic" "${SRC_DIRS[@]}"
RC_SCORE=$(grep -ioE 'score[: ]+[0-9]+(\.[0-9]+)?' "$RAW/rubycritic.txt" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
RC_SMELLS=$(grep -E 'Smells:' "$RAW/rubycritic.txt" | grep -oE '[0-9]+' | head -1)
RC_SMELLS="${RC_SMELLS:-?}"
echo "  rubycritic: score ${RC_SCORE:-?}, ${RC_SMELLS} smell(s)"

run_tool rubocop rubocop "$RAW/rubocop.txt" --no-server --format simple "${SRC_DIRS[@]}"
if grep -q 'no offenses detected' "$RAW/rubocop.txt" 2>/dev/null; then
  RUBOCOP=0
else
  RUBOCOP=$(num '[0-9]+ offenses? detected' "$RAW/rubocop.txt"); RUBOCOP="${RUBOCOP:-?}"
fi
echo "  rubocop: ${RUBOCOP} offense(s)"

# ---------------------------------------------------------------------------
# 3. PERFORMANCE (static portion)
# ---------------------------------------------------------------------------
echo "[3/6] Performance (static) — fasterer"
run_tool fasterer fasterer "$RAW/fasterer.txt"
FASTERER=$(grep -cE '\.rb:[0-9]+' "$RAW/fasterer.txt" 2>/dev/null); FASTERER="${FASTERER:-?}"
echo "  fasterer: ${FASTERER} speed suggestion(s)"

# ---------------------------------------------------------------------------
# 4b. RAILS CONVENTIONS
# ---------------------------------------------------------------------------
echo "[4/6] Rails conventions — rails_best_practices"
run_tool rails_best_practices rails_best_practices "$RAW/rails_best_practices.txt" .
RBP=$(num 'found [0-9]+ warning' "$RAW/rails_best_practices.txt"); RBP="${RBP:-?}"
echo "  rails_best_practices: ${RBP} warning(s)"

# ---------------------------------------------------------------------------
# 5. TECH DEBT FRESHNESS
# ---------------------------------------------------------------------------
echo "[5/6] Tech debt — bundle outdated"
( cd "$PROJECT" && bundle outdated --parseable ) >"$RAW/outdated.txt" 2>&1
OUTDATED=$(grep -cE '\(newest' "$RAW/outdated.txt" 2>/dev/null)
[[ "${OUTDATED:-0}" == "0" ]] && OUTDATED=$(grep -cE '^[a-z0-9_.-]+ \(' "$RAW/outdated.txt" 2>/dev/null)
OUTDATED="${OUTDATED:-?}"
echo "  bundle outdated: ${OUTDATED} gem(s) behind"

echo "[6/6] Writing report"

# ---------------------------------------------------------------------------
# REPORT
# ---------------------------------------------------------------------------
{
  echo "# Rails Health Audit — $(basename "$PROJECT")"
  echo
  echo "_Generated $STAMP. Phase 1 static scan. Raw output in \`tmp/health-audit/raw/\`._"
  echo
  echo "## Summary (most severe first)"
  echo
  echo "| Rank | Category | Tool | Finding |"
  echo "|------|----------|------|---------|"
  echo "| 1 | Security | brakeman | ${BRAKEMAN} warning(s) |"
  echo "| 1 | Security | bundler-audit | ${AUDIT} vulnerable advisory(ies) |"
  echo "| 3 | Performance | fasterer | ${FASTERER} speed suggestion(s) |"
  echo "| 4 | Maintainability | rubycritic | score ${RC_SCORE:-?}, ${RC_SMELLS:-?} smell(s) |"
  echo "| 4 | Maintainability | rubocop | ${RUBOCOP} offense(s) |"
  echo "| 4 | Rails conventions | rails_best_practices | ${RBP} warning(s) |"
  echo "| 5 | Tech debt | bundle outdated | ${OUTDATED} gem(s) behind |"
  echo
  echo "> Ranks 2 (data correctness) and the N+1 part of rank 3 need the app to boot —"
  echo "> see Phase 2 below."
  echo
  echo "## Phase 2 — runtime checks (follow-up, need app + DB)"
  echo
  echo "Add temporarily to \`Gemfile\` (\`:development\`/\`:test\`) and run in the project:"
  echo
  echo "- **Data correctness** — \`active_record_doctor\` → \`bundle exec rake active_record_doctor\`"
  echo "  (missing FKs, NOT NULL, unique indexes, model/DB mismatch)"
  echo "- **Missing indexes** — \`lol_dba\` → \`bundle exec rake db:find_indexes\`"
  echo "- **N+1 queries** — \`bullet\` (dev/test) or \`prosopite\`; exercise app / run tests"
  echo "- **Test coverage** — \`simplecov\` → run the suite, read \`coverage/index.html\`"
  echo
  echo "## Action plan"
  echo
  echo "_Fill in after review — one line per item: [Category] problem → fix → effort._"
  echo
  echo "1. [Security] ..."
  echo "2. [Data] ..."
  echo "3. [Perf] ..."
} > "$REPORT"

echo
echo "Done. Report → $REPORT"
