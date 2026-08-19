#!/usr/bin/env bash
# Install omp (https://omp.sh) on a GitHub Actions runner and put it on PATH.
# Safe to run locally. Adds ~/.bun/bin to $GITHUB_PATH when present.
set -euo pipefail

curl -fsSL https://omp.sh/install.sh | bash

export PATH="$HOME/.bun/bin:$PATH"
if [ -n "${GITHUB_PATH:-}" ]; then
  printf '%s\n' "$HOME/.bun/bin" >> "$GITHUB_PATH"
fi

command -v omp >/dev/null 2>&1 || {
  echo "::error::omp not found on PATH after install"
  exit 1
}

echo "omp $(omp --version) installed at $(command -v omp)"
