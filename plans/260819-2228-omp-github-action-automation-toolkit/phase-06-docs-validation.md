# Phase 6: Docs + End-to-End Validation

## Context Links
- [plan.md](../plan.md), all phase files

## Overview
- **Priority**: P1
- **Current status**: Pending
- README as the caller-facing contract; E2E proof of all four flows in a scratch repo;
  cleanup of scaffolding.

## Key Insights
- Callers need exactly: (1) copy a router workflow, (2) add secrets/vars, (3) add labels.
  README must be complete at those three steps — anything more is friction.
- Versioning: tag `v1`; callers pin `@v1`. Breaking prompt/workflow contract changes = `v2`.
- E2E is the only real proof — every flow gets one green scratch-repo run before "done".

## Requirements
### Functional
- README: quickstart (3 steps), flow table (label/trigger/output/permissions), secret setup
  (`OMP_API_KEY`, optional `OMP_GH_PAT`, optional `OMP_MODEL`/`OMP_MAX_MINUTES` vars),
  security notes (fork policy, environment gate, token scopes), cost controls
- All four flows demonstrated end-to-end in scratch repo; evidence links in run summary
- Spike workflow (Phase 1) removed; scripts pass `shellcheck` clean

### Non-functional
- README quickstart ≤ 20 lines to first green run
- Repo rules: update `docs/development-roadmap.md` + `docs/project-changelog.md` if present

## Architecture
Scratch repo matrix:
| Flow | Trigger artifact | Expected deliverable |
|---|---|---|
| auto-plan | issue w/ feature ask | plan comment |
| bug-triage | issue w/ bug report | triage comment |
| code-review | same-repo PR w/ seeded bug | review w/ inline finding |
| auto-implement | issue w/ small task | draft PR |

## Related Code Files
- Modify: `README.md`
- Delete: `.github/workflows/spike-install.yml`
- Create (this repo, if adopting docs convention): `docs/project-changelog.md` entry

## Implementation Steps
1. Write README sections above
2. Run the 4-flow matrix in scratch repo; capture run URLs + result screenshots/comments
3. `shellcheck scripts/*.sh`; fix findings
4. Tag `v1`
5. Negative tests: missing secret → clear failure comment; fork PR → guard comment
6. Update changelog/roadmap per repo documentation rules

## Todo List
- [ ] README complete (quickstart ≤20 lines)
- [ ] 4/4 flows green in scratch repo with evidence
- [ ] Negative tests pass
- [ ] shellcheck clean, spike removed, `v1` tagged

## Success Criteria
- A developer following only the README gets `auto-plan` working in their repo in one commit
- All flow evidence captured; no scaffold remnants

## Risk Assessment
| Risk | Mitigation |
|---|---|
| Scratch repo results not representative (tiny codebase) | Seed scratch repo with a realistic small TS project |
| Docs drift as prompts evolve | README links to flow table in this plan's structure; prompts self-document contracts |

## Security Considerations
- README documents the `omp-review` environment approval gate for cautious callers
- No example secrets in docs; placeholders only

## Next Steps
- Post-v1 candidates (explicitly out of scope now): follow-up comments resuming omp
  sessions (`--resume`), scheduled triage sweeps, multi-provider routing
