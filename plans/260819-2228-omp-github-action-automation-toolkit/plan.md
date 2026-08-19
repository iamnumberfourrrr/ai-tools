# OMP GitHub Action Automation Toolkit

## Goal
Reusable GitHub Actions toolkit (`ai-tools` repo) that runs headless `omp` (omp.sh) on
GitHub-hosted runners, triggered by issue/PR labels, credentials supplied via repo secrets.

Four flows: `auto-plan`, `bug-triage`, `code-review`, `auto-implement`.

## Decisions (locked with user)
| Decision | Choice |
|---|---|
| Consumption | Reusable toolkit — caller repos reference workflows via `uses:` |
| Runner | GitHub-hosted `ubuntu-latest`, omp installed per-run via `omp.sh/install.sh` |
| auto-implement output | Branch + draft PR, never direct push to main |
| code-review target | PR-labeled trigger (not issues) |

## Verified facts
- Install: `curl -fsSL https://omp.sh/install.sh | bash` (redirects to `can1357/oh-my-pi/scripts/install.sh`; bootstraps Bun if missing)
- Headless auth: provider env vars (`ZHIPU_CODING_PLAN_API_KEY`, `ANTHROPIC_API_KEY`, ...) or `--api-key` flag
- Headless exec: `omp -p --mode json --approval-mode yolo --max-time <dur> --no-session`
- Triggers: `on: issues: types: [labeled]` / `on: pull_request_target: types: [labeled]`
- Reusable workflows MUST live in `.github/workflows/` of this repo to be `uses:`-callable

## Architecture
```
ai-tools/
├── .github/workflows/          # reusable workflows (the product)
│   ├── omp-auto-plan.yml
│   ├── omp-bug-triage.yml
│   ├── omp-code-review.yml
│   └── omp-auto-implement.yml
├── scripts/
│   ├── install-omp.sh          # pinned install
│   ├── render-prompt.sh        # template + gh context -> prompt file
│   ├── run-omp.sh              # headless invocation w/ timeouts + exit handling
│   └── post-result.sh          # issue comment / PR review / draft PR
├── prompts/                    # one prompt template per flow
└── README.md                   # caller wiring guide
```

Caller repo adds ONE thin router workflow (label → `uses:` the right reusable workflow,
`secrets: inherit`). Secrets: `OMP_API_KEY` (+ optional `OMP_MODEL` var).

## Phases
| Phase | File | Status |
|---|---|---|
| 1. Scaffold + install spike | [phase-01-scaffold-install.md](phase-01-scaffold-install.md) | Done |
| 2. Core runner workflow + scripts | [phase-02-core-runner.md](phase-02-core-runner.md) | Done |
| 3. Issue flows: auto-plan + bug-triage | [phase-03-issue-flows.md](phase-03-issue-flows.md) | Done |
| 4. PR flow: code-review | [phase-04-code-review.md](phase-04-code-review.md) | Done |
| 5. Write flow: auto-implement | [phase-05-auto-implement.md](phase-05-auto-implement.md) | Done |
| 6. Docs + end-to-end validation | [phase-06-docs-validation.md](phase-06-docs-validation.md) | Done |

- All jobs: explicit minimal `permissions:`, `concurrency` per issue/PR, `timeout-minutes`
- `pull_request_target` (fork) risk handled via same-repo guard + protected environment
- No secrets in logs; `OMP_API_KEY` masked; prompts carry issue body (prompt-injection surface — prompts instruct omp to treat issue text as data, not instructions)
