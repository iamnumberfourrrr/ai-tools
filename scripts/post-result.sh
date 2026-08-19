#!/usr/bin/env bash
# Deliver flow results. Subcommands:
#   issue-comment <issue-number> <marker> <body.md>
#   pr-review    <pr-number> <summary.md> <findings.json|->   (JSON array or -)
#   draft-pr     <issue-number> <branch> <body.md>            (create/update)
# Requires: GH_TOKEN, GITHUB_REPOSITORY
set -euo pipefail

repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"
: "${GH_TOKEN:?GH_TOKEN not set}"

cmd="${1:?usage: post-result.sh <issue-comment|pr-review|draft-pr> ...}"
shift

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1"; }

body_with_run_link() {
  # Appends run provenance so users can trace a comment to its CI run.
  local body
  body=$(cat "$1")
  if [ -n "${GITHUB_RUN_ID:-}" ]; then
    printf '%s\n\n---\n*via [run %s](https://github.com/%s/actions/runs/%s)*\n' \
      "$body" "${GITHUB_RUN_ID}" "$repo" "${GITHUB_RUN_ID}"
  else
    printf '%s\n' "$body"
  fi
}

case "$cmd" in
  issue-comment)
    number="${1:?issue number required}"
    marker="${2:?marker required (e.g. omp:auto-plan)}"
    body="${3:?body.md required}"
    # Idempotent: edit existing comment carrying this marker, else create.
    existing=$(gh api "repos/$repo/issues/$number/comments?per_page=100" \
      --jq ".[] | select(.body | contains(\"<!-- $marker -->\")) | .id" | head -1 || true)
    if [ -n "$existing" ]; then
      gh api -X PATCH "repos/$repo/issues/comments/$existing" \
        -F body="$(printf '<!-- %s -->\n\n%s' "$marker" "$(body_with_run_link "$body")")" >/dev/null
      echo "updated comment $existing"
    else
      gh api -X POST "repos/$repo/issues/$number/comments" \
        -F body="$(printf '<!-- %s -->\n\n%s' "$marker" "$(body_with_run_link "$body")")" >/dev/null
      echo "created comment on issue #$number"
    fi
    ;;

  pr-review)
    number="${1:?pr number required}"
    summary="${2:?summary.md required}"
    findings="${3:--}"
    comments_json="[]"
    if [ "$findings" != "-" ] && [ -s "$findings" ]; then
      # Only valid positions survive; the rest collapse into the summary.
      comments_json=$(jq -c '[.[] | select(.path != null and .position != null) |
        {path, position, body: ("**" + .severity + "** — " + .message)}]' "$findings")
    fi
    gh api -X POST "repos/$repo/pulls/$number/reviews" \
      -F body="$(body_with_run_link "$summary")" \
      -F event=COMMENT \
      -F "comments=$comments_json" >/dev/null
    echo "posted review on PR #$number ($(echo "$comments_json" | jq length) inline)"
    ;;

  draft-pr)
    issue="${1:?issue number required}"
    branch="${2:?branch required}"
    body="${3:?body.md required}"
    title="omp: implement #$issue"
    # One PR per issue: reuse open PR with this head branch, else create.
    existing=$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' || true)
    if [ -n "$existing" ] && [ "$existing" != "null" ]; then
      gh pr edit "$existing" --title "$title" --body "$(body_with_run_link "$body")" >/dev/null
      echo "updated PR #$existing"
    else
      gh pr create --draft --title "$title" --body "$(body_with_run_link "$body")" \
        --head "$branch" >/dev/null
      echo "created draft PR for #$issue on $branch"
    fi
    ;;

  *)
    echo "::error::unknown command: $cmd" >&2
    exit 1
    ;;
esac
