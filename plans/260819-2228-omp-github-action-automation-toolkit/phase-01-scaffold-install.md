# Phase 1: Scaffold + Install Spike

## Context Links
- [plan.md](../plan.md)
- Install script source: `https://raw.githubusercontent.com/can1357/oh-my-pi/main/scripts/install.sh`

## Overview
- **Priority**: P0 — foundation
- **Current status**: Pending
- Scaffold the toolkit repo layout and prove omp installs + runs headless on a GitHub-hosted
  runner. Everything else depends on this spike being green.

## Key Insights
- `install.sh` bootstraps Bun when missing; ubuntu-latest images ship Bun but version may
  drift — the script's own bootstrap is the canonical path, don't fight it.
- omp is a Bun single-file binary; no global state needed beyond `~/.omp` (profile isolation
  via `--profile ci` keeps the runner clean).
- Local omp is v17.2.9 — pin the toolkit to a known-good install (record resolved version in
  job output, don't hard-pin the script URL unless it breaks).

## Requirements
### Functional
- Repo directories exist: `.github/workflows/`, `scripts/`, `prompts/`
- `scripts/install-omp.sh` installs omp to a writable prefix and prints `omp --version`
- Smoke: `omp -p "reply OK"` exits 0 with model output (requires a key)

### Non-functional
- Install step < 60s on ubuntu-latest
- No sudo beyond what install.sh itself does

## Architecture
`install-omp.sh` is the single install entrypoint reused by every workflow job:

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -fsSL https://omp.sh/install.sh | bash
export PATH="$HOME/.bun/bin:$PATH"
omp --version
```

## Related Code Files
- Create: `scripts/install-omp.sh`, `README.md` (stub), `.gitignore`
- Create: `.github/workflows/spike-install.yml` (temp, removed in Phase 6)

## Implementation Steps
1. `git init` if needed; create directory tree
2. Write `scripts/install-omp.sh` (above)
3. Write `spike-install.yml`: `workflow_dispatch` job on ubuntu-latest — install, then
   `OMP_API_KEY: ${{ secrets.OMP_API_KEY }} omp -p --no-session "Reply with the single word OK"`
4. Push, add `OMP_API_KEY` secret (zhipu coding-plan key), run dispatch, observe green run

## Todo List
- [ ] Directory tree scaffolded
- [ ] install-omp.sh committed
- [ ] Spike workflow green on GitHub-hosted runner
- [ ] `--api-key` vs provider env var verified (whichever the spike proves)

## Success Criteria
- A `workflow_dispatch` run on ubuntu-latest installs omp and returns model output, exit 0
- Resolved omp version recorded in the run log

## Risk Assessment
| Risk | Mitigation |
|---|---|
| `--api-key` flag not honored for zhipu-coding-plan provider | Fall back to exporting `ZHIPU_CODING_PLAN_API_KEY`; spike decides |
| install.sh rate-limited or moved | Script is a thin redirect to GitHub raw; pin to raw URL if omp.sh breaks |
| Bun missing on runner | install.sh bootstraps it; spike confirms |

## Security Considerations
- Secret only via `secrets.OMP_API_KEY` env mapping; never echoed
- Spike workflow deleted after proof (no long-lived dispatch surface that burns tokens)

## Next Steps
- Phase 2 builds the core runner job on this foundation
