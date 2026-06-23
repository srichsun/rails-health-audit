#!/usr/bin/env bash
# Rails Health Audit — single entry point. THIS is the command to run.
#
#   bash audit.sh /path/to/rails/project
#
# It runs both phases into ONE report folder:
#   1. Static scan  (always works — only reads source + Gemfile.lock)
#   2. Runtime scan (best-effort — runs only if the app boots and its DB is migrated;
#                    if not, it's skipped and the report says how to enable it)
#
# The result is one report: tmp/health-audit/report-<timestamp>/health-audit-report.md
# Then fill the Action plan and export the PDF (see the printed next steps).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PROJECT="${1:-$PWD}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd)" || { echo "No such directory: ${1:-}"; exit 1; }

# 1. Static — must succeed.
bash "$HERE/audit-static.sh" "$PROJECT" || exit 1

# 2. Runtime — best effort. A failure here (app won't boot / no DB) is not fatal;
#    the report keeps its "not run yet" runtime note in the "Still to run" section.
echo
echo "→ Runtime checks: trying to boot the app against its DB…"
if bash "$HERE/audit-dynamic.sh" "$PROJECT"; then
  :
else
  echo "  ↳ skipped — the report's \"Still to run\" section explains how to enable it"
  echo "    (set up + migrate the DB, then re-run this command)."
fi

RUN="$(ls -dt "$PROJECT"/tmp/health-audit/report-* 2>/dev/null | head -1)"
echo
echo "=================================================================="
echo "Report folder: $RUN"
echo
echo "Next steps:"
echo "  1. Fill the '## 2. Action plan' table in health-audit-report.md"
echo "     (this is the judgment step — rank findings, cite file:line)."
echo "  2. Export the shareable PDF:"
echo "       bash \"$HERE/export.sh\" \"$PROJECT\""
echo "=================================================================="
