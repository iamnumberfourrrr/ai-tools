# Project Changelog

## 0.1.0 — 2026-08-19

Initial release: omp-driven GitHub Actions toolkit with four label-triggered
flows, validated end-to-end on this repo (dogfooded via `router.yml`).

### Added
- Reusable workflows: `omp-issue-flow.yml` (auto-plan, bug-triage),
  `omp-code-review.yml` (auto-review, same-repo PRs only),
  `omp-auto-implement.yml` (draft-PR implement flow).
- `router.yml` — caller-side label router to copy into consuming repos.
- Scripts: `install-omp.sh`, `fetch-context.sh`, `render-prompt.sh`,
  `run-omp.sh` (env-var auth mapping, no key in argv), `post-result.sh`
  (anchored comments, PR reviews with inline findings, idempotent draft PRs).
- Prompts with shared trust-boundary header; 4-backtick fenced context with
  fence-balance guard.

### Security
- Fork PR guard on auto-review (pull_request_target exfil path).
- Workflow-file edits excluded from omp pushes + disclosed in PR body.
- Optional `OMP_GH_PAT` for PR creation and CI-triggering pushes.
- Minimal per-flow GITHUB_TOKEN scopes; router declares the ceiling.

### Fixed during E2E validation
- jq slurp indexing in fetch-context (undefined `$issue`/`$comments`).
- GH expression arithmetic (`+`) unsupported — explicit `job-timeout-minutes`.
- Number inputs into reusable workflows need `fromJSON` coercion.
- `$GITHUB_ENV` writes don't apply within the same step (branch name).
- Nested toolkit checkout + flow artifacts leaking into implement commits
  (runner-local `.git/info/exclude`).
- PR review API requires a JSON array body (`--input`), not `-F` string.
- Run-link URL duplication; bare code fence in review prompt.

### E2E evidence (this repo)
- auto-plan: run [32272922861](https://github.com/iamnumberfourrrr/ai-tools/actions/runs/32272922861) → plan comment on #1
- bug-triage: run [32273186499](https://github.com/iamnumberfourrrr/ai-tools/actions/runs/32273186499) → triage on #2 (surfaced 3 real defects)
- auto-implement: run [32275204383](https://github.com/iamnumberfourrrr/ai-tools/actions/runs/32275204383) → draft PR #3
- auto-review: run [32275726050](https://github.com/iamnumberfourrrr/ai-tools/actions/runs/32275726050) → review + inline finding on PR #3
