---
name: om-prepare-test-env
description: Repo-local extension recording why om-skills-learning-lab has no generated test-environment entrypoint. Read before attempting generation here, and before any skill tries to attach to a baseUrl in this repository.
---

# om-prepare-test-env — repo-local notes for `om-skills-learning-lab`

This extends the installed `om-prepare-test-env`; it never relaxes its rules. Its
only purpose is to stop a future run from re-paying the cost of a discovery whose
answer is already known.

## Why no entrypoint script exists

**This repository has no application to run.** Generation was entered on
2026-08-16, discovery completed, and it concluded there is nothing to bring up —
so `.ai/scripts/test-env-up.ps1` and `.ai/scripts/test-env-down.ps1` were
deliberately **not** generated. This is the documented Phase 2 fallback
("when a reliable script cannot be generated"), reached because the environment
is absent rather than because scripting it failed.

Evidence gathered, so the next run does not have to repeat it:

- No `package.json`, `Dockerfile`, `docker-compose*.yml`, `Makefile`,
  `Taskfile.yml`, `justfile`, `requirements.txt`, `pyproject.toml`, `go.mod`, or
  `Cargo.toml` is tracked anywhere in the 185 committed files.
- There is no `.github/` directory at all, so no CI workflow documents a run
  recipe either.
- `AGENTS.md` states it directly in its task-routing table: *"Application code,
  tests, CI — **TODO** — none exists yet. This repo has no source tree, test
  suite, or `.github/workflows/`."* `README.md` agrees: *"There is no
  application code here."*
- The only browsable artifacts are `learning-map/om-skills-learning-map-v*.html`
  (v14 is newest). These are self-contained single files that the README says to
  open directly in a browser; they need no server, so serving them would invent a
  target rather than reflect one.

## Machine facts discovered (2026-08-16, Windows 11)

Recorded because they cost a probe to establish and they shape any future
generation here:

- **Docker is not installed.** No ephemeral service containers are possible on
  this machine. Nothing in the repo needs one, so this blocks nothing today.
- Available: `node` v24.15.0, `python` 3.11.15 (as `python`, **not** `python3` —
  that name hits the Windows Store alias and fails), `jq` 1.8.1, `curl` 8.21.0,
  Windows PowerShell 5.1. **`pwsh` (PowerShell 7+) is absent**, so any generated
  `.ps1` must run under 5.1 and stay ASCII-only per the skill's encoding rule.
- Git Bash is present, but the chosen script flavor for this repo is **`.ps1`**,
  matching the repo's committed launchers (`lab-status.ps1`, `lab-report.ps1`)
  and the `powershell -NoProfile -ExecutionPolicy Bypass -File …` invocation that
  `AGENTS.md` documents.

## What consumers must do

`.ai/qa/test-env.json` is written with `"status": "no-app"` and
`"baseUrl": null`. Skills that need a live UI — `om-auto-qa-pr`,
`om-integration-tests` — must **report the limitation honestly and skip browser
verification**, never fabricate a base URL or attach to an unrelated server.
Review, spec, and PR skills are unaffected: this repo's validation gate is
`git diff --check` and needs no running environment.

The `agent-browser` provider was intentionally left uninstalled. Installing it
would download a release binary plus Chrome for Testing to drive an application
that does not exist. The descriptor at `.ai/browsers/agent-browser.md` is
known-good and self-provisioning, so a future run can install it in one step the
moment there is something to point it at.

## Re-attempt trigger

Re-run `om-prepare-test-env --regenerate` when **any** of these becomes true —
each one invalidates the conclusion above:

1. A dependency manifest or `Dockerfile`/compose file is committed.
2. A `.github/workflows/` file appears that builds or runs something.
3. The `AGENTS.md` "Application code, tests, CI" row stops saying **TODO**.
4. A deliberate decision is made to serve `learning-map/` over HTTP so the maps
   can be QA'd in a browser as a real page rather than a local file.

For case 4 specifically, the shape is already worked out and needs no discovery:
a background static server rooted at `learning-map/` on a free `127.0.0.1` port,
indexed at the newest map, health-checked with one `GET /` — no services, no
build chain, no build cache to speak of, so the up script collapses to the lock,
the reuse check, the server launch, and the descriptor write. Prefer `node` over
`python` for it, since `python3` is not a usable name on this machine.
