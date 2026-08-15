# Final gate — 2026-08-15-lab-report

**Fired:** 2026-08-15T16:30:00Z, with every Tasks row `done`.
**Subsumes:** the checkpoint that would otherwise have fired at Step 1.6.
**Branch:** `feat/lab-report` — 8 commits on top of `origin/main`.

## Full validation gate

`validation.commands` in `.ai/agentic.config.json` is a single command, and it is
the repository's entire gate by design (`AGENTS.md` § Validation, `SDLC.md`):
there is no compiler, linter, or test runner because the content is Markdown and
scripts rather than compiled code.

| Command | Scope | Result |
|---|---|---|
| `git diff --check` | working tree vs index | ✅ exit `0` |
| `git diff --check origin/main...HEAD` | the branch diff actually being shipped | ✅ exit `0` |

The second run is deliberate. The spec for `lab-status.ps1` already recorded that
`git diff --check` on a clean checkout compares the working tree to the index and
therefore certifies almost nothing; running it across the branch diff is what
actually checks the shipped content for trailing whitespace and conflict markers.

## Shipped diff

```text
A  .ai/runs/2026-08-15-lab-report/HANDOFF.md
A  .ai/runs/2026-08-15-lab-report/NOTIFY.md
A  .ai/runs/2026-08-15-lab-report/PLAN.md
A  .ai/runs/2026-08-15-lab-report/checkpoint-1-checks.md
A  .ai/scripts/lab-report.ps1
M  AGENTS.md
M  README.md
```

Confirmed absent from the diff, as the plan's Non-goals require:

- `.ai/specs/2026-08-15-lab-report.md` — materialized into the worktree for
  reference and never committed; it merges through its own spec PR #11.
- `.ai/scripts/lab-status.ps1` — untouched.
- Anything under `.agents/skills/`, `.ai/trackers/`, `.ai/browsers/`, or
  `.ai/agentic.config.json`.
- The working checkout's `.claude/skills/` entries.

## Integration suite

**Skipped — the repository has no integration suite.** There is no application,
no test runner, and no test directory; `validation.commands` is `git diff --check`
alone. The `om-integration-tests` skill is also not installed in this repository,
but that is not the operative reason: even installed, it would have nothing to
run. Recorded here explicitly rather than passed over silently.

## Design-system / style compliance pass

**Skipped — no such tooling exists here.** There is no design-system skill under
`.ai/skills/`, no style-lint command in the config, and no UI surface in the
change. No `X.Y-ds-fix` Steps were appended.

## Verification standing in for a test suite

With no assertion framework available, the spec's verification fixture is the
test procedure, and it is the substantive evidence behind this gate. Twenty-eight
cases across the five implementation Steps passed against two scratch clones under
`$env:TEMP` — full matrix in `checkpoint-1-checks.md`. It caught four real defects
before their commits landed, including one that silently produced no output at all
while still exiting `0`, and one that made every spec title fall back to its
filename.

**This is a genuine gap, not a satisfied requirement.** The skill's rule that every
code change ships with tests cannot be met by a framework in a repository that has
none, and the PR summary says so plainly rather than implying coverage that does
not exist.

## End-to-end behavior on a checkout with real discovery entries

The linked worktree has no `.claude/` of its own — it is gitignored and exists
only in the primary checkout — so a run there correctly reports `0 of 18`
resolving and says so. The faithful stand-in is the scratch clone with 18 real
NTFS junctions, which produces the healthy report end to end:

```text
The lab is on branch `feat/lab-report` with a clean working tree. All 18 installed
skills are vendored, recorded in the lockfile, and dispatchable from this
checkout. 1 spec is on record, and the learning log holds 4 experiments and 16
findings.

No notes.
```

## Fixture cleanup

Both scratch clones (`lab-report-fixture`, `lab-report-fixture2`) and the
second-clone target used for the "foreign junction" case live under `$env:TEMP`
and are removed at run end. Nothing was ever created inside the repository.
