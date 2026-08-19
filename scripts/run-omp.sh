#!/usr/bin/env bash
# Run omp headless. Exports the provider's canonical API key env var from
# OMP_API_KEY so the key never appears in argv (ps-visible).
#
# Env:
#   OMP_API_KEY       secret (optional locally — omp falls back to stored auth)
#   OMP_PROVIDER      default: zhipu-coding-plan
#   OMP_API_ENV       override the env var name directly (escapes the table)
#   OMP_MODEL         optional model (fuzzy match)
#   OMP_MAX_MINUTES   wall-clock budget for omp, default 15
#   OMP_CWD           working repo dir, default PWD
# Args: <prompt.md> [out.md]
# Stderr -> omp.log. Exit code = omp exit code; partial stdout preserved.
set -euo pipefail

prompt="${1:?usage: run-omp.sh <prompt.md> [out.md]}"
out="${2:-out.md}"
log="${OMP_LOG:-omp.log}"

provider="${OMP_PROVIDER:-zhipu-coding-plan}"
minutes="${OMP_MAX_MINUTES:-15}"
cwd="${OMP_CWD:-$PWD}"
model="${OMP_MODEL:-}"

if [ -n "${OMP_API_KEY:-}" ]; then
  api_env="${OMP_API_ENV:-}"
  if [ -z "$api_env" ]; then
    case "$provider" in
      zhipu-coding-plan) api_env=ZHIPU_API_KEY ;;
      anthropic)         api_env=ANTHROPIC_API_KEY ;;
      openai)            api_env=OPENAI_API_KEY ;;
      google)            api_env=GEMINI_API_KEY ;;
      openrouter)        api_env=OPENROUTER_API_KEY ;;
      groq)              api_env=GROQ_API_KEY ;;
      *)
        echo "::error::no env-var mapping for provider '$provider'; set OMP_API_ENV" >&2
        exit 1
        ;;
    esac
  fi
  export "$api_env=$OMP_API_KEY"
  echo "auth: exported \$$api_env for provider $provider"
else
  echo "auth: OMP_API_KEY empty — relying on omp's stored/env auth" >&2
fi

args=( -p --no-session --mode text --auto-approve --max-time "${minutes}m" --cwd "$cwd" )
[ -n "$model" ] && args+=( --model "$model" )
args+=( "@$prompt" )

echo "omp ${args[*]%%@*}@$prompt (max ${minutes}m)"
set +e
omp "${args[@]}" > "$out" 2> "$log"
code=$?
set -e

bytes=$(wc -c < "$out" | tr -d ' ')
echo "omp exit=$code, stdout $bytes bytes, log: $log"
[ "$bytes" -gt 0 ] || {
  echo "::error::omp produced no output; log tail:" >&2
  tail -50 "$log" >&2 || true
}
exit "$code"
