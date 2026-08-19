# Phase 4: PR Flow — code-review

## Context Links
- [plan.md](../plan.md), [phase-02-core-runner.md](phase-02-core-runner.md)

## Overview
- **Priority**: P1
- **Current status**: Pending
- `auto-review` label on a PR → omp reviews the diff, posts a PR review
  (summary + inline comments where possible).

## Key Insights
- Trigger is `pull_request_target: types: [labeled]` — required so the job (a) sees labels
  on PRs from forks, (b) has secrets access. This is the dangerous event: it runs with the
  BASE repo's token and secrets while the PR head is potentially untrusted fork code.
- omp EXECUTES bash on the checked-out code (tests, greps). On a fork PR that's
  untrusted code execution WITH `OMP_API_KEY` in env → exfiltration vector.
  Mitigations (both, not either):
  1. **Same-repo guard**: job fails unless `head.repo.full_name == repository` (fork PRs get
     a "push branch to repo or ask maintainer" comment instead).
  2. **Protected environment**: job requests `environment: omp-review` whose secrets hold
     `OMP_API_KEY`; callers MAY configure required reviewers on that environment for an
     approval click-gate before any fork-adjacent run.
- Checkout the merge ref (`refs/pull/<n>/merge`) for review context.

## Requirements
### Functional
- Label `auto-review` on same-repo PR → PR review posted: verdict, findings by severity,
  each with file+line and rationale, nitpicks separated from blockers
- Fork PR → explanatory comment, no run, no secret use
- Retry = remove/re-add label (edits prior review summary if still latest)

### Non-functional
- `permissions: contents: read, pull-requests: write`
- `max-minutes: 20` default
- Inline comments via `gh api repos/{r}/pulls/{n}/reviews` with `comments[]` payloads
  (position-based on the diff, fall back to summary-only on API mismatch)

## Architecture
```yaml
on:
  pull_request_target: { types: [labeled] }
jobs:
  review:
    if: github.event.label.name == 'auto-review'
    environment: omp-review          # secret lives here, not repo level
    steps:
      - name: same-repo guard
        run: test "${{ github.event.pull_request.head.repo.full_name }}" = "${{ github.repository }}"
      # checkout merge ref, fetch base diff, install omp, render, run, post-review
```

## Related Code Files
- Create: `.github/workflows/omp-code-review.yml`
- Create: `prompts/code-review.md`
- Modify: `scripts/post-result.sh` (`pr-review` subcommand)

## Implementation Steps
1. Workflow with guard → checkout merge ref → `git diff origin/${base}...HEAD > /tmp/diff.patch`
2. Prompt: review diff + targeted file reads; output contract = JSON findings block followed
   by prose (scripts parse the fenced JSON for inline positions)
3. `post-result.sh pr-review`: POST review (EVENT: COMMENT, body + inline comments);
   findings lacking valid positions collapse into the summary body
4. Negative test: fork PR (or simulated `head.repo` mismatch) → guard comment, no omp run

## Todo List
- [ ] Same-repo PR review posted with inline findings
- [ ] Fork guard proven (no secrets consumed)
- [ ] Summary-only fallback works when positions reject

## Success Criteria
- Scratch repo PR with an injected bug → review flags it with file/line; guard test logs
  show zero omp invocation on fork-simulated PRs

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Fork exfiltration via `pull_request_target` | Same-repo guard + environment-gated secret (defense in depth) |
| Diff > context window | Prompt instructs omp to read files itself; diff passed as pointer+stats, not full blob |
| Position API rejects stale hunks | Fallback path above |

## Security Considerations
- `OMP_API_KEY` scoped to `omp-review` environment ONLY in this flow
- Review content is model output on untrusted-ish code — posted as COMMENT event, never
  APPROVE/REQUEST_CHANGES (no automated gate changes)

## Next Steps
- Phase 5: auto-implement (write path, draft PR)
