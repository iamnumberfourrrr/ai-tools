#!/usr/bin/env bash
# Render a prompt template: replace the <!-- omp:context --> marker line with
# the fenced JSON context block.
# Usage: render-prompt.sh <template.md> <context.json> [output.md]
set -euo pipefail

template="${1:?usage: render-prompt.sh <template.md> <context.json> [output.md]}"
context="${2:?usage: render-prompt.sh <template.md> <context.json> [output.md]}"
output="${3:-prompt.md}"

[ -f "$template" ] || { echo "::error::template not found: $template" >&2; exit 1; }
[ -f "$context" ] || { echo "::error::context not found: $context" >&2; exit 1; }
grep -q '<!-- omp:context -->' "$template" || {
  echo "::error::template $template has no <!-- omp:context --> marker" >&2
  exit 1
}

awk -v ctx="$context" '
  /<!-- omp:context -->/ {
    print "```json"
    while ((getline line < ctx) > 0) print line
    close(ctx)
    print "```"
    seen = 1
    next
  }
  { print }
  END { exit seen ? 0 : 1 }
' "$template" > "$output"

echo "rendered $output ($(wc -l < "$output") lines)"
