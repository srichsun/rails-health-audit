#!/usr/bin/env bash
# Rails Health Audit — optional export of the markdown report to HTML / PDF.
# Usage: bash export.sh /path/to/rails/project [html|pdf|both]   (default: html)
#
# Markdown stays the source of truth (editable, diffable, zero-dependency). This is just
# a polished, shareable rendering on top:
#   - HTML: rendered with kramdown (pure Ruby, via `gem exec` — nothing installed)
#   - PDF:  printed from the HTML with headless Chrome (already on most machines)
set -uo pipefail

PROJECT="${1:-$PWD}"
PROJECT="$(cd "$PROJECT" 2>/dev/null && pwd)" || { echo "No such directory: ${1:-}"; exit 1; }
FORMAT="${2:-html}"

OUT="$PROJECT/tmp/health-audit"
[[ -d "$OUT" ]] || { echo "No report found at $OUT — run audit-static.sh first."; exit 1; }

md_to_html() { # <md-file> <html-file> <title>
  local md="$1" html="$2" title="$3"
  local body
  if command -v kramdown >/dev/null 2>&1; then
    body=$(kramdown "$md" 2>/dev/null)
  else
    body=$(gem exec -g kramdown kramdown "$md" 2>/dev/null)
  fi
  [[ -z "$body" ]] && { echo "  ✗ could not render $md (kramdown failed)"; return 1; }
  cat > "$html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${title}</title>
<style>
  body { font: 16px/1.6 -apple-system, system-ui, "Segoe UI", sans-serif;
         color: #1f2328; max-width: 820px; margin: 40px auto; padding: 0 24px; }
  h1, h2, h3 { line-height: 1.25; }
  h1 { font-size: 1.8em; } h2 { font-size: 1.35em; border-bottom: 1px solid #d0d7de;
       padding-bottom: .3em; margin-top: 1.8em; }
  table { border-collapse: collapse; width: 100%; margin: 1em 0; font-size: .95em; }
  th, td { border: 1px solid #d0d7de; padding: 6px 12px; text-align: left; vertical-align: top; }
  th { background: #f6f8fa; }
  code { background: #f6f8fa; padding: .15em .35em; border-radius: 4px;
         font: .88em ui-monospace, "SF Mono", Menlo, monospace; }
  pre { background: #f6f8fa; padding: 14px; border-radius: 8px; overflow-x: auto; }
  pre code { background: none; padding: 0; }
  blockquote { margin: 1em 0; padding: .2em 1em; color: #57606a;
               border-left: 4px solid #d0d7de; }
  a { color: #0969da; }
</style>
</head>
<body>
${body}
</body>
</html>
HTML
  echo "  ✓ $html"
}

html_to_pdf() { # <html-file> <pdf-file>
  local html="$1" pdf="$2"
  local chrome=""
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome 2>/dev/null)" \
    "$(command -v chromium 2>/dev/null)"; do
    [[ -x "$c" ]] && { chrome="$c"; break; }
  done
  if [[ -z "$chrome" ]]; then
    echo "  ✗ no Chrome/Chromium found — open $html in a browser and 'Print → Save as PDF'."
    return 1
  fi
  "$chrome" --headless --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$pdf" "file://$html" >/dev/null 2>&1
  [[ -f "$pdf" ]] && echo "  ✓ $pdf" || echo "  ✗ PDF render failed for $html"
}

echo "Exporting reports in $OUT (format: $FORMAT)"
for md in "$OUT/REPORT.md" "$OUT/PASS2.md"; do
  [[ -f "$md" ]] || continue
  base="${md%.md}"
  title="Rails Health Audit — $(basename "$base")"
  md_to_html "$md" "$base.html" "$title" || continue
  [[ "$FORMAT" == "pdf" || "$FORMAT" == "both" ]] && html_to_pdf "$base.html" "$base.pdf"
  # html-only run: keep the .html; for pdf-only, the .html is the intermediate (kept too)
done
echo "Done."
