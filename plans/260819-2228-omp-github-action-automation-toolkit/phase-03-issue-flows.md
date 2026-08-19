# Phase 3: Issue Flows — auto-plan + bug-triage

## Context Links
- [plan.md](../plan.md), [phase-02-core-runner.md](phase-02-core-runner.md)

## Overview
- **Priority**: P1
- **Current status**: Pending
- Two read-only flows triggered by `auto-plan` / `bug-triage` labels on issues. Both post
  results as an issue comment. Thin wrappers over the Phase 2 runner.

## Key Insights
- Label-triggered `issues` events fire once per label add — natural dedupe. Re-adding a
  removed label re-triggers (intentional: that's the "retry" UX).
- Read-only enforcement: pass `--no-tools` is too strict (omp needs read/search tools);
  instead the prompt mandates read-only AND the job's GITHUB_TOKEN gets NO write scopes, so
  even a prompt-injected `git push` has no credentials that matter. Belt = prompt, suspenders = token scopes.
- Comment format: `<!-- omp:task=plan run=<run_id> -->` HTML anchor for idempotent re-runs
  (edit existing comment on retry rather than spamming new ones).

## Requirements
### Functional
- `omp-auto-plan.yml`: label `auto-plan` → plan doc posted as comment (goal, approach,
  file-level changes, phases, risks, open questions)
- `omp-bug-triage.yml`: label `bug-triage` → triage comment (severity guess, root-cause
  hypothesis with file:line evidence, repro gap analysis, suggested labels, next actions)
- Both: reaction 👀 on trigger, ✅/❌ on completion; failure comment includes run URL
- Retry = remove + re-add label

### Non-functional
- `permissions: contents: read, issues: write`
- Default `max-minutes: 15`

## Architecture
Caller router workflow (documented in README, tested in Phase 6):
```yaml
on:
  issues: { types: [labeled] }
jobs:
  route:
    if: contains(fromJSON('["auto-plan","bug-triage"]'), github.event.label.name)
    uses: tunguyen/ai-tools/.github/workflows/omp-issue-flow.yml@v1
    with:
      task: ${{ github.event.label.name }}
    secrets: inherit
```
Shared `omp-issue-flow.yml` dispatches prompt by task — one YAML for both flows (DRY);
`auto-plan`/`bug-triage` stay distinct labels and prompts.

## Related Code Files
- Create: `.github/workflows/omp-issue-flow.yml` (single reusable, `task` input)
- Create: `prompts/auto-plan.md`, `prompts/bug-triage.md`
- Modify: `scripts/post-result.sh` (`issue-comment` subcommand with anchor dedupe)

## Implementation Steps
1. Write `omp-issue-flow.yml`: gate on label name set, call Phase-2 steps inline (reusable
   workflows can't chain `uses:` to another reusable workflow's jobs and keep event context
   — so issue-flow inlines runner steps; scripts keep it ~30 lines)
2. Write both prompts: preamble + context block + task-specific output contract
3. `post-result.sh issue-comment`: search existing `<!-- omp:task=X -->` comment → PATCH or POST
4. Trigger via scratch repo issue (Phase 6 formalizes; smoke here)

## Todo List
- [ ] omp-issue-flow.yml green for both labels in scratch repo
- [ ] Prompts produce structured, anchored comments
- [ ] Retry (label re-add) edits the same comment

## Success Criteria
- Scratch repo: label `auto-plan` → ≤15 min later a plan comment anchored to the run;
  label `bug-triage` on a real-looking bug → triage comment citing file:line evidence

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Plan quality varies by model | Prompt pins output contract; model configurable per caller |
| Comment > 64KB limit | post-result truncates with pointer to artifact |

## Security Considerations
- Read-only flows: GITHUB_TOKEN has no `contents: write`; omp bash can't push
- Issue author ≠ labeler — labeler (triage+ permission) is the trusted actor; issue body
  remains untrusted data

## Next Steps
- Phase 4: PR review flow (different trigger + delivery)
