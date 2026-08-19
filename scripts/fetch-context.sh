#!/usr/bin/env bash
# Fetch GitHub context (issue or PR) into context.json for prompt rendering.
# Usage: fetch-context.sh <issue|pr> <number>
# Requires: GH_TOKEN, GITHUB_REPOSITORY
set -euo pipefail

mode="${1:?usage: fetch-context.sh <issue|pr> <number>}"
number="${2:?usage: fetch-context.sh <issue|pr> <number>}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"
: "${GH_TOKEN:?GH_TOKEN not set}"

case "$mode" in
  issue)
    gh api "repos/$repo/issues/$number" > /tmp/issue.json
    # Last 20 comments, bodies capped at 2000 chars each.
    gh api --paginate "repos/$repo/issues/$number/comments" \
      --jq '[.[] | {author: .user.login, created_at, body: (.body[:2000])}]' > /tmp/comments.json
    jq -s --arg repo "$repo" --arg run_id "${GITHUB_RUN_ID:-}" '{
      mode: "issue",
      repository: $repo,
      run_id: $run_id,
      issue: {
        number: .[0].number,
        title: .[0].title,
        author: .[0].user.login,
        labels: [.[0].labels[].name],
        body: .[0].body,
        comments: .[1]
      }
    }' /tmp/issue.json /tmp/comments.json > context.json
    ;;
  pr)
    gh api "repos/$repo/pulls/$number" > /tmp/pr.json
    gh api "repos/$repo/pulls/$number/files?per_page=100" > /tmp/files.json
    jq -s --arg repo "$repo" --arg run_id "${GITHUB_RUN_ID:-}" '{
      mode: "pr",
      repository: $repo,
      run_id: $run_id,
      pull_request: {
        number: .[0].number,
        title: .[0].title,
        author: .[0].user.login,
        base: .[0].base.ref,
        head: .[0].head.ref,
        body: .[0].body,
        files: [.[1][] | {path, additions, deletions, changes}]
      }
    }' /tmp/pr.json /tmp/files.json > context.json
    ;;
  *)
    echo "::error::unknown mode: $mode (expected 'issue' or 'pr')" >&2
    exit 1
    ;;
esac

echo "context.json written ($(wc -c < context.json) bytes)"
