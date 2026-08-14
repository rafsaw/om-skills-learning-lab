# Execution plan — lab status check

Source doc: .ai/specs/2026-08-13-lab-status-check.md

## Goal

Ship `.ai/scripts/lab-status.ps1`, a read-only Windows PowerShell 5.1 script that
answers "is this repo ready for the next learning session?" in a couple of
seconds — printing branch and working-tree state, skill-discovery health, and the
latest recorded experiment and finding, then a `READY` / `NOT READY` verdict
backed by its exit code (`0` ready, `1` blockers found, `2` wrong context).

The check the script exists for is discovery resolution: a `.claude\skills\<name>`
entry that is missing, is a real directory rather than a link, is a link with no
target, or resolves into a *different* checkout. That last case looks perfectly
healthy to an existence test while silently dispatching another repository's copy
of the skill.

## Scope

In scope:

- One new file, `.ai/scripts/lab-status.ps1`.
- Two short documentation pointers: the repository map and "Start here" in
  `README.md`, and one routing-table row in `AGENTS.md`.

Non-goals (deferred to Phase 2 by decision D9 in the spec, and explicitly out of
scope for this plan):

- `gh` / `jq` presence and version checks, upstream ahead/behind reporting, a
  `git diff --check` validation-gate check, active-worktree diagnostics, remote
  or tracker state, per-finding remediation commands, `-Json`, `-Remote`, and
  lockfile hash verification.
- Any change under `.agents/skills/`, `.ai/trackers/`, `.ai/browsers/`, or
  `.ai/agentic.config.json`.
- Any change to the working checkout's `.claude/skills/` entries. On this machine
  they are junctions created without elevation; a mis-restored entry cannot
  simply be recreated, so every negative test runs against a scratch clone under
  `$env:TEMP` instead.
- Correcting the repo-wide documentation that calls the discovery entries
  "symlinks" when they are in fact NTFS junctions. The script accepts both link
  types, so it is correct either way, and the doc fix is a separate change.

## Verification fixture

Steps 2–4 need broken repositories to test against. Each is built as a scratch
clone outside the repository, with the discovery entries recreated as junctions
(which need no elevation or Developer Mode), and deleted when the step is done:

```powershell
$fixture = Join-Path $env:TEMP "lab-status-fixture"
git clone --no-hardlinks . $fixture
New-Item -ItemType Directory -Path "$fixture\.claude\skills" | Out-Null
Get-ChildItem "$fixture\.agents\skills" -Directory | ForEach-Object {
  New-Item -ItemType Junction -Path "$fixture\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
Copy-Item .\.ai\scripts\lab-status.ps1 "$fixture\.ai\scripts\lab-status.ps1"
```

Because the script anchors on `$PSScriptRoot`, the copy inside the fixture
reports on the fixture, never on the real checkout.

## Implementation Plan

### Phase 1: the minimal status report

1. **Script skeleton and anchor check.** `#Requires -Version 5.1`,
   `Set-StrictMode -Version Latest`, `[CmdletBinding()]` with a `[switch]$Help`
   parameter and usage text, error handling that keeps the report going, repo
   root resolved two levels up from `$PSScriptRoot`, the
   `.agents\skills\` + `.ai\agentic.config.json` anchor check with `exit 2`, the
   two finding lists, and a `main` that prints the three (still empty) section
   headings and the verdict.
2. **Repository section.** Current branch and working-tree cleanliness from
   `git -C $RepoRoot`, the dirty-tree warning, and degradation of both lines to
   `unavailable` when `git` is absent or the anchored root is not a work tree.
3. **Skills section.** Enumerate `.agents\skills\`, classify each entry against
   `.claude\skills\` as `ok` / `missing` / `not-a-link` / `broken` / `foreign`,
   accepting both `SymbolicLink` and `Junction` and comparing targets normalized
   and case-insensitively; add the `orphan` and missing-`SKILL.md` warnings; read
   `skills-lock.json` with `ConvertFrom-Json` inside a `try` and report the
   symmetric difference, degrading to `unreadable` on any failure.
4. **Learning log section.** Fence-aware line scan of `EXPERIMENTS.md` and
   `FINDINGS.md`, matching `^##\s+(Experiment|Finding)\s+(\d{3})\b` outside code
   fences only, highest number per file, separators trimmed off the title,
   truncated for display, `none recorded` plus a warning when nothing matches.
5. **Verdict and documentation pointers.** Render the accumulated findings with
   `[blocker]` / `[warning]` prefixes and the single `README.md` pointer, set the
   exit code from the blocker count, then add the script to the `README.md`
   repository map (noting it is hand-maintained rather than a generated
   launcher), to "Start here" as the fastest confirmation that discovery works,
   and to the `AGENTS.md` routing table.

## Risks

- **No PowerShell linter in this repo.** The validation gate is
  `git diff --check`, so a syntax error would ship unnoticed. Mitigated by
  parsing the file with `[System.Management.Automation.PSParser]::Tokenize()` in
  step 1 and by running the script in healthy and broken states before the PR is
  finalized.
- **PowerShell 5.1 only.** `pwsh` is not installed on the development machine, so
  the script must avoid PowerShell 7 syntax (`??`, ternaries,
  `ConvertFrom-Json -AsHashtable`) and the two-argument
  `[System.IO.Path]::GetFullPath` overload, which does not exist on .NET
  Framework.
- **False confidence.** `READY` means the checks this script knows about passed,
  not that nothing is wrong. Mitigated by a verdict line that names counts rather
  than making an absolute claim.
- **Blast radius near zero.** Nothing in the pipeline dispatches this script, so
  a bug in it cannot fail a PR, a review, or a merge — the worst outcome is a
  wrong report on a terminal. Rollback is deleting the file and reverting the two
  documentation pointers.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: the minimal status report

- [ ] 1.1 Script skeleton and anchor check
- [ ] 1.2 Repository section
- [ ] 1.3 Skills section
- [ ] 1.4 Learning log section
- [ ] 1.5 Verdict and documentation pointers
