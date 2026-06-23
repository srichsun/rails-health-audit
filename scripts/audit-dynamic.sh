#!/usr/bin/env bash
# Rails Health Audit — Pass 2 runtime checks.
# Usage: bash audit-dynamic.sh /path/to/rails/project
#
# Unlike pass 1 (which only reads source), this BOOTS the app against its database,
# so the project must already be set up: `bundle check` passes, the DB exists and is
# migrated. It adds active_record_doctor + lol_dba through a TEMPORARY bundle so the
# project's own Gemfile / Gemfile.lock are never modified.
#
# It runs the data-correctness + indexing detectors (the high-value runtime checks).
# N+1 (bullet/prosopite) and coverage (simplecov) still need the app exercised /
# the test suite run, so they remain documented follow-ups, not automated here.
set -uo pipefail

PROJECT="${1:-$PWD}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd)" || { echo "No such directory: ${1:-}"; exit 1; }

if [[ ! -f "$PROJECT/Gemfile" || ! -f "$PROJECT/config/application.rb" ]]; then
  echo "Not a Rails project: $PROJECT"; exit 1
fi

STAMP="$(date '+%Y-%m-%d %H:%M')"      # human-readable, shown inside the report
# Append into the most recent static report folder, so static + runtime are ONE report.
OUT="$PROJECT/tmp/health-audit"
RUN="$(ls -dt "$OUT"/report-* 2>/dev/null | head -1)"
if [[ -z "$RUN" || ! -f "$RUN/health-audit-report.md" ]]; then
  echo "  ✗ no static report found — run audit-static.sh first."; exit 1
fi
RAW="$RUN/raw_original_result"
mkdir -p "$RAW"
REPORT="$RUN/health-audit-report.md"

echo "Rails Health Audit — Pass 2 (runtime) → $PROJECT"

# --- the app must boot against its DB ---
if ! ( cd "$PROJECT" && bundle check >/dev/null 2>&1 ); then
  echo "  ✗ bundle is not satisfied (run 'bundle install' in the project first)."; exit 1
fi
TABLES=$( cd "$PROJECT" && bundle exec rails runner "print ActiveRecord::Base.connection.tables.size" 2>/dev/null )
if [[ -z "$TABLES" ]]; then
  echo "  ✗ could not connect to the database / boot the app. Set up the DB first."; exit 1
fi
echo "  app boots, DB reachable ($TABLES tables)"

# --- temporary bundle: project Gemfile + our two tools, project files untouched ---
TMPGEM="$(mktemp /tmp/rha_pass2_gemfile.XXXXXX)"
cat > "$TMPGEM" <<EOF
eval_gemfile "$PROJECT/Gemfile"
gem "active_record_doctor"
gem "lol_dba"
EOF
cleanup() { rm -f "$TMPGEM" "$TMPGEM.lock"; }
trap cleanup EXIT

echo "  installing pass-2 tools in a temporary bundle..."
if ! ( cd "$PROJECT" && BUNDLE_GEMFILE="$TMPGEM" bundle install >/dev/null 2>&1 ); then
  echo "  ✗ could not install pass-2 tools."; exit 1
fi

run_rake() { ( cd "$PROJECT" && BUNDLE_GEMFILE="$TMPGEM" bundle exec rake "$1" 2>&1 ); }
# Keep only finding lines; drop rake/bundler noise, stack traces, and DB errors.
clean() { grep -viE 'funding|bundle fund|^rake aborted|^/|:in .|--trace|^Tasks:|^Caused by:|^LINE |^\s*\^|StatementInvalid|PG::|Mysql2::|does not exist|^ERROR|^$'; }

# Run high-value active_record_doctor detectors one by one, so a crash in one
# (e.g. a table living in a secondary DB) doesn't abort the rest.
DETECTORS=(
  missing_unique_indexes
  missing_non_null_constraint
  missing_foreign_keys
  unindexed_foreign_keys
  incorrect_dependent_option
)

echo "[1/2] active_record_doctor (data correctness + indexing)"
: > "$RAW/pass2_ar_doctor.txt"
AR_ROWS=""   # report table rows (Bash 3.2 has no associative arrays)
AR_TOTAL=0   # total active_record_doctor findings, for the Overview row
for det in "${DETECTORS[@]}"; do
  raw_out=$(run_rake "active_record_doctor:$det")
  if printf '%s' "$raw_out" | grep -qiE 'StatementInvalid|rake aborted|does not exist'; then
    # Detector crashed — usually a model whose table lives in a secondary database.
    n="errored"
    body="(detector errored — often a model whose table lives in a secondary database)"
  else
    body=$(printf '%s\n' "$raw_out" | clean)
    n=$(printf '%s\n' "$body" | grep -cve '^$')
    AR_TOTAL=$(( AR_TOTAL + n ))
  fi
  AR_ROWS="${AR_ROWS}| ${det} | ${n} |"$'\n'
  { echo "### $det ($n)"; printf '%s\n' "$body"; echo; } >> "$RAW/pass2_ar_doctor.txt"
  echo "  $det: $n finding(s)"
done

echo "[2/2] lol_dba (missing indexes from associations)"
run_rake db:find_indexes | clean > "$RAW/pass2_lol_dba.txt"
LOLDBA=$(grep -cE '^\s*add_index' "$RAW/pass2_lol_dba.txt")
echo "  lol_dba: ${LOLDBA} missing index(es) suggested"

# --- splice the runtime results into the ONE health report (static + runtime) ---
OVR="$(mktemp /tmp/rha_ovr.XXXXXX)"   # the two Overview rows to add
PH2="$(mktemp /tmp/rha_ph2.XXXXXX)"   # the filled Phase 2 section
trap 'cleanup; rm -f "$OVR" "$PH2"' EXIT

{
  echo "| 🔴 2 | Data correctness | active_record_doctor | ${AR_TOTAL} issue(s) | \`raw_original_result/pass2_ar_doctor.txt\` |"
  echo "| 🟡 3 | Performance | lol_dba | ${LOLDBA} missing index(es) | \`raw_original_result/pass2_lol_dba.txt\` |"
} > "$OVR"

{
  echo "## 3. Phase 2 — runtime checks (ran against the app + DB)"
  echo
  echo "_Booted the app against its database ($STAMP). Raw output in \`raw_original_result/\`._"
  echo
  echo "### Data correctness & indexing"
  echo
  echo "| Detector | Findings |"
  echo "|----------|----------|"
  printf '%s' "$AR_ROWS"
  echo "| lol_dba (missing indexes) | ${LOLDBA} |"
  echo
  echo "See \`raw_original_result/pass2_ar_doctor.txt\` and \`raw_original_result/pass2_lol_dba.txt\` for the specific tables/columns."
  echo
  echo "### Still manual (need the app exercised, not just booted)"
  echo
  echo "- **N+1 queries** — add \`bullet\` (dev/test) or \`prosopite\`, then run the suite or"
  echo "  click through the app; N+1s only surface on code paths that actually execute."
  echo "- **Test coverage** — run the suite with \`simplecov\`, read \`coverage/index.html\`."
} > "$PH2"

# Replace the RUNTIME_OVERVIEW_ROWS marker with the two rows, and the whole
# PHASE2_START..PHASE2_END placeholder block with the filled section.
awk -v ovr="$OVR" -v ph2="$PH2" '
  /<!-- RUNTIME_OVERVIEW_ROWS -->/ { while ((getline l < ovr) > 0) print l; next }
  /<!-- PHASE2_START -->/ { while ((getline l < ph2) > 0) print l; skip=1; next }
  /<!-- PHASE2_END -->/   { skip=0; next }
  skip { next }
  { print }
' "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"

echo
echo "Done. Runtime results merged into → $REPORT"
