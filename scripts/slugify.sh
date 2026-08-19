#!/usr/bin/env bash
# Slugify stdin: lowercase, collapse runs of non-alphanumerics to single
# hyphens, cap at 40 chars, strip a trailing hyphen. Empty or all-symbol
# input yields an empty slug (exit 0); callers apply their own fallback
# (the auto-implement workflow uses ${slug:-task}).
# Usage: echo "Add a Slugify utility script" | slugify.sh
set -euo pipefail

tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/-$//'
