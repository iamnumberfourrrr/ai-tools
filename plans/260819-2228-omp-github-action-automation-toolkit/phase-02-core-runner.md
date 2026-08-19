# Phase 2: Core Runner Workflow + Scripts

## Context Links
- [plan.md](../plan.md), [phase-01-scaffold-install.md](phase-01-scaffold-install.md)

## Overview
- **Priority**: P0 — shared engine
- **Current status**: Pending
- One reusable workflow (`omp-runner.yml`, `workflow_call`) + three scripts that all four
  flows wrap. Flows differ only in prompt template and delivery action.

## Key Insights
- Reusable workflows run in the CALLER's context: `actions/checkout` grabs the caller repo,
  `github.event.*` is the caller's issue/PR event. The toolkit repo is never checked out
  except to read its own scripts — use `actions/checkout` with `repository: tunguyen/ai-tools`
  + `ref` input pinned, or `raw.githubusercontent.com` fetch. Decision: checkout toolkit repo
  to a side dir (scripts+prompts versioned with the workflow ref — atomic).
- `omp -p` output goes to stdout; capture to `out.md` for posting. `--max-time` enforces
  wall-clock budget; `--approval-mode yolo` is required for unattended tool use.
- Prompt = template + fetched context (issue body, labels, comments via `gh api`) rendered by
  `render-prompt.sh`. Issue text is DATA: templates instruct omp to treat it as untrusted
  input, never as instructions (prompt-injection guard).

## Requirements
### Functional
- `omp-runner.yml` inputs: `task` (plan|triage|review|implement), `model`, `max-minutes`,
  `context-json` (issue/PR payload fields), `omp-args`
- Renders `prompts/<task>.md` with context, runs omp headless, saves output
- Delivery delegated to flow-specific steps (Phases 3-5)
- Job summary always written (run URL, duration, exit code) even on failure

### Non-functional
- `concurrency: group: omp-${{ inputs.task }}-${{ github.event.issue.number || github.event.pull_request.number }}`, no cancel-in-progress (paid work shouldn't be killed mid-flight)
- `timeout-minutes` = max-minutes + 10 hard ceiling
- OMP_API_KEY from caller via `secrets: inherit`; fail fast with clear message if absent

## Architecture
```yaml
# .github/workflows/omp-runner.yml  (workflow_call)
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4            # caller repo (event context)
      - uses: actions/checkout@v4            # toolkit repo -> ./ai-tools
        with: { repository: <toolkit>, ref: ${{ inputs.toolkit-ref }}, path: ai-tools }
      - run: ./ai-tools/scripts/install-omp.sh
      - run: ./ai-tools/scripts/render-prompt.sh   # -> prompt.md
      - run: ./ai-tools/scripts/run-omp.sh         # -> out.md
      - uses: actions/upload-artifact@v4      # out.md + logs, always()
```

`run-omp.sh` core:
```bash
exec omp -p --no-session --mode text \
  --model "$OMP_MODEL" --api-key "$OMP_API_KEY" \
  --approval-mode yolo --max-time "${OMP_MAX_MINUTES}m" \
  --cwd "$REPO_DIR" @prompt.md > out.md 2> omp.log
```
(exit code propagated; omp.log attached to artifact on failure)

## Related Code Files
- Create: `.github/workflows/omp-runner.yml`
- Create: `scripts/render-prompt.sh`, `scripts/run-omp.sh`, `scripts/post-result.sh`
- Create: `prompts/_header.md` (shared injection-guard preamble)

## Implementation Steps
1. Write `omp-runner.yml` with inputs/defaults above
2. `render-prompt.sh`: `envsubst`-free simple replace — `__CONTEXT_JSON__` placeholder →
   heredoc-injected JSON block under the preamble
3. `run-omp.sh` with secret-absent guard, timeout propagation, artifact-friendly logs
4. `post-result.sh`: subcommands `issue-comment | pr-review | draft-pr` (used by Phases 3-5)
5. Local dry-run of scripts with fake context (bash-only, no GH needed)

## Todo List
- [ ] omp-runner.yml callable with typed inputs
- [ ] render/run/post scripts pass local dry-run
- [ ] Failure path produces artifact + job summary

## Success Criteria
- Calling `omp-runner.yml` from a scratch repo with `task: plan` produces non-empty `out.md`
  artifact and a green (or gracefully-failed) job with summary

## Risk Assessment
| Risk | Mitigation |
|---|---|
| omp exits non-zero mid-plan (model refusal, budget) | run-omp.sh captures partial stdout + exits with omp's code; flows post partial output with failure banner |
| Context JSON breaks prompt formatting | JSON fenced in ```block inside template |
| Toolkit ref drift breaks callers | `toolkit-ref` input defaults to the major tag (v1) |

## Security Considerations
- `OMP_API_KEY` never in args visible via `ps` on shared runner — prefer env var export over
  `--api-key` flag if spike (Phase 1) shows provider env var works; decision recorded there
- Prompt-injection preamble in every template: issue/PR text is data
- Minimal permissions declared per flow in Phases 3-5, not blanket-inherited

## Next Steps
- Phase 3 wraps the runner with the two issue flows
