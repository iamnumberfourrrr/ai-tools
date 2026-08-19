# Phase 5: Write Flow — auto-implement

## Context Links
- [plan.md](../plan.md), [phase-02-core-runner.md](phase-02-core-runner.md)

## Overview
- **Priority**: P1
- **Current status**: Pending
- `auto-implement` label on an issue → omp works on a branch, pushes, opens a DRAFT PR
  linked to the issue. Never pushes to main.

## Key Insights
- Needs a PAT or fine-grained token if the caller wants the PR to trigger CI workflows
  (default `GITHUB_TOKEN` PRs don't fire `on: push/pull_request` in the same repo).
  Decision: support both — `OMP_GH_PAT` secret optional; fall back to `GITHUB_TOKEN`
  (PR opens fine, CI on the PR just won't run — documented).
- Branch naming: `omp/<issue-number>-<slug>` — deterministic, dedupes retries (force-push
  update on re-run, one PR per issue).
- Run lint/tests BEFORE pushing: prompt contract requires omp to run the repo's own
  check commands; `run-omp.sh` exit code reflects it. Push happens only on green or
  explicitly-documented partial state.
- Issue flow only (no fork dimension): labeler must have write access.

## Requirements
### Functional
- Label `auto-implement` → branch `omp/<n>-<slug>`, commits, draft PR titled
  `omp: implement #<n>`, body = summary + what changed + verification evidence + limitations
- PR description links back `Closes #<n>` ONLY as draft note (human removes draft → merge)
- Re-run (label re-add): force-push same branch, update existing PR body
- Failure mid-run: comment on issue with what was attempted + run artifact URL

### Non-functional
- `permissions: contents: write, pull-requests: write, issues: write`
- `max-minutes: 45` default (longest flow)
- Git identity: `omp-automation <noreply@users.noreply.github.com>`; commit message
  conventional format with `refs #<n>`, no AI-claims per repo commit rules

## Architecture
```
label → guard(label name) → checkout(default branch) → branch omp/<n>-<slug>
→ render prompt (issue + linked context) → omp yolo (--cwd repo, max-time)
→ git diff --exit-code? (nothing done → comment "no changes needed")
→ run repo checks (as instructed by omp in-session; verified in PR body)
→ push -u origin branch → gh pr create --draft (or edit existing)
→ comment on issue with PR link
```

## Related Code Files
- Create: `.github/workflows/omp-auto-implement.yml`
- Create: `prompts/auto-implement.md`
- Modify: `scripts/post-result.sh` (`draft-pr` subcommand)

## Implementation Steps
1. Workflow per architecture above; `OMP_GH_PAT` optional (`gh auth` prefers PAT env)
2. Prompt contract: implement minimal correct change, run existing checks, list exact
   verification commands + their output tails, explicitly state unimplemented parts
3. `post-result.sh draft-pr`: find existing `omp:` head PR on branch → edit; else create
4. Nothing-to-do path: diff empty → issue comment, clean exit
5. Scratch-repo test with a small, well-specified issue

## Todo List
- [ ] Draft PR created from labeled issue in scratch repo
- [ ] Retry updates same branch/PR (no duplicates)
- [ ] Failure + no-change paths produce useful issue comments

## Success Criteria
- Scratch repo: `auto-implement` label on "add util fn X with test" → draft PR containing
  implementation + test, checks-run evidence in body, issue comment linking PR

## Risk Assessment
| Risk | Mitigation |
|---|---|
| omp pushes junk to protected branch | GITHUB_TOKEN scoped; branch protection on main recommended to callers |
| Runaway cost on hard tasks | `--max-time` 45m hard stop + job `timeout-minutes` ceiling |
| Duplicate PRs on retries | Deterministic branch + existing-PR lookup |

## Security Considerations
- `OMP_GH_PAT` (if used): fine-grained, scoped to caller repo, contents+PRs only
- Commit content is model-authored — draft PR gate keeps human review mandatory
- Prompt-injection via issue body could steer commits; blast radius = a draft PR a human
  reviews (same trust boundary as any contributor PR)

## Next Steps
- Phase 6: README + end-to-end validation of all four flows
