# ai-tools — OMP GitHub Actions Toolkit

Run [omp](https://omp.sh) (headless coding agent) on GitHub-hosted runners,
triggered by issue/PR labels. Four flows:

| Label | Trigger | Output |
|---|---|---|
| `auto-plan` | issue | implementation-plan comment (anchored, edited on retry) |
| `bug-triage` | issue | triage comment: verdict, root-cause w/ `path:line` evidence, next actions |
| `auto-review` | PR | PR review with severity-ranked inline findings |
| `auto-implement` | issue | branch `omp/<n>-<slug>` + draft PR with verification evidence |

## Quickstart (caller repo)

1. Add the secrets `OMP_API_KEY` (your omp provider API key) and, for
   auto-implement, `OMP_GH_PAT` (PAT with `repo` + `workflows` scopes — see
   [Security](#security)).
2. Copy [`.github/workflows/router.yml`](.github/workflows/router.yml) into your
   repo, replacing `iamnumberfourrrr/ai-tools` references if you forked.
   Optional: set repo vars `OMP_PROVIDER` (default `zhipu-coding-plan`) and
   `OMP_MODEL`.
3. Create the labels `auto-plan`, `bug-triage`, `auto-review`,
   `auto-implement`, then label an issue or PR.

Retry any flow: remove and re-add the label. Issue comments are edited in place
(anchored via `<!-- omp:task -->` HTML comments), implement re-runs force-push
the same branch and update the same PR.

## How it works

```
label ──▶ router.yml ──▶ reusable workflow (issue-flow / code-review / auto-implement)
                             │ checkout caller repo + this toolkit @ toolkit-ref
                             │ fetch-context.sh  → context.json (issue/PR + comments)
                             │ render-prompt.sh  → prompt.md (template + 4-backtick-fenced JSON)
                             │ install-omp.sh    → omp via omp.sh/install.sh
                             │ run-omp.sh        → omp -p --auto-approve --max-time Nm
                             └ post-result.sh    → issue comment / PR review / draft PR
```

Provider auth: `run-omp.sh` maps `OMP_API_KEY` to the provider's canonical env
var (`zhipu-coding-plan` → `ZHIPU_API_KEY`, `anthropic` → `ANTHROPIC_API_KEY`,
`openai` → `OPENAI_API_KEY`, `google` → `GEMINI_API_KEY`, `openrouter` →
`OPENROUTER_API_KEY`, `groq` → `GROQ_API_KEY`; override with `OMP_API_ENV`) so
the key never appears in argv.

## Inputs (all optional unless marked)

Every reusable workflow accepts: `model`, `max-minutes` (omp budget: 15/20/45
defaults), `job-timeout-minutes` (hard ceiling), `toolkit-ref` (default `main`;
pin a tag for stability). Required: `task` + `issue-number`, or `pr-number`.

## Security

- **Permissions flow down**: your router's `permissions:` block is the ceiling;
  each called workflow narrows further (`contents: read, issues: write` for
  read-only flows). Never grant more than the union your flows need.
- **Fork PRs are refused** by `auto-review` (`pull_request_target` would run
  untrusted checkout with your provider key in env). Same-repo branches only.
- **omp cannot edit workflow files**: auto-implement reverts staged
  `.github/workflows/**` changes and discloses it in the PR body. This is
  deliberate — label-triggered automation that edits its own permissions is an
  exfiltration path. Use `OMP_GH_PAT` (workflows scope) to opt in knowingly.
- **GITHUB_TOKEN cannot open PRs** on repos with default settings ("Allow
  GitHub Actions to create and approve pull requests" off). `OMP_GH_PAT`
  also solves this; PAT-opened PRs additionally trigger your CI.
- **Prompt injection**: every prompt carries a trust-boundary header; issue/PR
  text is fenced as data. Fence-balance guard fails the render if untrusted
  content breaks out of the context block.
- `OMP_API_KEY` is exported as a provider env var, never logged, never in argv.

## Repo layout

- `.github/workflows/` — `router.yml` (copy me) + three reusable workflows
- `scripts/` — install / fetch-context / render-prompt / run-omp / post-result
- `prompts/` — `_header.md` (shared trust boundary) + one template per flow

## Development

`shellcheck scripts/*.sh` and `actionlint .github/workflows/*.yml` must pass.
E2E: the router dogfoods this repo itself — see `docs/project-changelog.md`
for the validated flow matrix and run links.
