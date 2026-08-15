# Execution plan — 2026-08-15-lab-report

**Branch:** `feat/lab-report`
**Source spec:** `.ai/specs/2026-08-15-lab-report.md`
**Spec PR:** #11 (design-only; this run ships the implementation on its own PR)
**Engine:** `om-auto-create-pr-loop` (steps: n/a, `--loop`: yes)

## Tasks

> Authoritative status table. `Status` is one of `todo` or `done`. On landing a Step, flip `Status` to `done` and fill the `Commit` column with the short SHA. The first row whose `Status` is not `done` is the resume point for `om-auto-continue-pr-loop`. Step ids and `Exec` cells are immutable once the plan is committed — per-Step commits touch only `Status` and `Commit`.

| Phase | Step | Title | Exec | Status | Commit |
|-------|------|-------|------|--------|--------|
| 1 | 1.1 | Create the script skeleton and the emit path | inline | done | pending |
| 1 | 1.2 | Implement the Repository section | inline | todo | — |
| 1 | 1.3 | Implement the Installed skills section | inline | todo | — |
| 1 | 1.4 | Implement the Specs section | inline | todo | — |
| 1 | 1.5 | Implement the Learning artifacts section, the Summary, and escaping | inline | todo | — |
| 1 | 1.6 | Make it discoverable | inline | todo | — |

**Why every Step is `inline`.** The six Steps build one file, each layering onto helpers the previous Step introduced (the anchor, the renderer's escaping helpers, the fence-aware scanner), so a fresh executor session would re-derive the same accumulated context for each one. Per `references/task-planning.md`, that is exactly the case `inline` describes: executor overhead would exceed the work. This run additionally operates under a session constraint that prohibits spawning subagents unless the user asks, which makes `inline` the only available placement — recorded here so the choice is auditable rather than silent.

## Goal

Add `.ai/scripts/lab-report.ps1`, a read-only Windows PowerShell 5.1 script that renders the current state of the Learning Lab as a single Markdown document: repository status, installed skills, available specs, the `FINDINGS.md` / `EXPERIMENTS.md` learning artifacts, and a generated summary paragraph.

## Scope

- One new file: `.ai/scripts/lab-report.ps1`.
- Two short documentation pointers: a row in `README.md`'s repository map and a routing row in `AGENTS.md`.

## Non-goals

Explicitly not touched by this run, per the spec's "Out of scope for this plan":

- `.ai/scripts/lab-status.ps1` — the readiness gate stays exactly as it is. The report defers every discovery *diagnosis* to it rather than restating or sharing its classification.
- Anything under `.agents/skills/`, `.ai/trackers/`, or `.ai/browsers/`.
- `.ai/agentic.config.json` — read for one value at run time, never modified.
- The `.claude/skills/` entries of the working checkout. No step may touch them: on a machine without symlink privilege a mis-restored entry cannot simply be recreated, so every negative test runs against a scratch clone under `$env:TEMP`.
- The spec document itself. It is materialized into this worktree for reference but deliberately excluded from every commit — it merges through its own spec PR #11.
- Phase 2 of the spec (`-Json`, tracker/remote state, ahead/behind, hash verification, per-spec implementation status, `-Since`, a byte-stable mode, an `om-lab-report` skill wrapper).

## Risks

1. **No test runner exists in this repository.** `validation.commands` is `git diff --check` and `AGENTS.md` states there is no compiler, linter, or test runner. The skill rule "every code change MUST include tests" therefore cannot be satisfied by a test framework here. Mitigation: the spec's own verification fixture is executed as the test procedure — a scratch clone under `$env:TEMP` driven into each broken state, plus `[System.Management.Automation.PSParser]::Tokenize()` as a parse check — and the results are recorded in the checkpoint and final-gate check files rather than asserted by a runner. This is a real gap, not a satisfied requirement, and it is surfaced in the PR summary.
2. **Duplication with `lab-status.ps1` drifting.** Three readers overlap. Mitigation: the spec names the three must-not-diverge behaviors (the anchor rule, accepting both `SymbolicLink` and `Junction`, normalized case-insensitive target comparison) and this run copies them deliberately rather than approximating them.
3. **PowerShell 5.1 encoding traps.** `>` redirection writes UTF-16LE, `Set-Content -Encoding UTF8` emits a BOM, and `Get-Content` without `-Encoding UTF8` decodes with the host ANSI code page. Mitigation: the file write goes through `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`, every read passes `-Encoding UTF8`, and the `>` trap is documented in `-Help`.
4. **Markdown breakage from unescaped repository text.** A `|` in a commit subject or spec title would break a table for every downstream reader. Mitigation: escaping is centralized in the renderer and verified explicitly in Step 1.5.

## External References

None. No `--skill-url` was passed, and this run fetches nothing.

## Implementation Plan

### Phase 1 — the report

#### Step 1.1 — Create the script skeleton and the emit path

Add `.ai/scripts/lab-report.ps1` with `#Requires -Version 5.1`, `Set-StrictMode -Version Latest`, `[string]$OutFile` and `[switch]$Help` parameters, usage text, root resolution from `$PSScriptRoot` with the `.agents\skills\` + `.ai\agentic.config.json` anchor check and exit `2`, `$SpecsDir` resolution (read `paths.specs` inside a `try`, fall back to `.ai/specs`), the collect/render split as empty functions, and the emit function writing either to stdout or to `-OutFile` via `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`.

*Verify:* title, generated-at line, and five empty section headings print, exit `0`; `-Help` prints usage and exits `0`; `-OutFile` produces a file with no BOM matching stdout; `-OutFile` into a nonexistent directory exits `2` and creates nothing; a copy outside the lab exits `2` with a stderr diagnostic; `PSParser::Tokenize()` reports no parse errors.

#### Step 1.2 — Implement the Repository section

Branch, HEAD sha/subject/date, and working-tree entry count via `git -C $RepoRoot`. Render the table, degrade every field to `unavailable` with a note when `git` is missing or the root is not a work tree, and add the dirty-tree note.

*Verify:* the real checkout renders branch, HEAD, and `clean`; a scratch file in the fixture yields `dirty (1 entry)` and the note with exit `0`; with `git` off `PATH` every field reads `unavailable` and the other sections still render; a detached HEAD renders `(detached at <sha>)`.

#### Step 1.3 — Implement the Installed skills section

Enumerate `.agents\skills\`, read `skills-lock.json` inside a `try`, enumerate `.claude\skills\` once, and classify each discovery entry as `resolves` / `does not resolve` — accepting both `SymbolicLink` and `Junction`, comparing targets through `GetFullPath()` case-insensitively. Emit the header counts, the four-column table including rows for lockfile-only and discovery-only names, and the discovery and lockfile-drift notes.

*Verify (fixture only):* untouched fixture reports every skill `resolves`; a deleted junction, a real directory, a broken target, and a repointed junction each yield `does not resolve`; an extra `.claude\skills\om-ghost` gets its own row; invalid JSON in `skills-lock.json` makes the Lockfile column `-` with a note and no crash.

#### Step 1.4 — Implement the Specs section

Enumerate `*.md` directly under `$SpecsDir`, parse the leading `YYYY-MM-DD` from each filename, read the first `# ` heading outside a code fence for the title (falling back to the filename stem), sort newest first, and render the table with repo-relative forward-slash paths. Handle missing and empty directories.

*Verify:* the real checkout lists the existing specs with titles and dates; a spec whose only `# ` heading is inside a fence falls back to the filename stem; a file without a date prefix renders a blank date and still appears; a nonexistent `paths.specs` prints the missing-directory line plus a note with exit `0`; an empty directory prints `No specs recorded.` with no note.

#### Step 1.5 — Implement the Learning artifacts section, the Summary, and escaping

Scan `EXPERIMENTS.md` and `FINDINGS.md` with fence tracking and `^##\s+(Experiment|Finding)\s+(\d{3})\b`, de-duplicate by number, render the count, the latest entry, and the three most recent. Generate the summary paragraph from the collected data and emit the `Notes:` list or `No notes.` Route every interpolated value through the table-cell and code-span escaping helpers.

*Verify:* correct counts and latest entries on the real checkout; `## Experiment 999` inside a fence changes nothing while the same heading outside a fence becomes the latest; a deleted `FINDINGS.md` prints `No entries recorded.` with a note and exit `0`; a commit subject containing `|` and a spec title containing `|` both render without breaking their tables; a healthy fixture ends with `No notes.` and a three-way-broken fixture lists exactly three notes.

#### Step 1.6 — Make it discoverable

Add `.ai/scripts/lab-report.ps1` to the repository map in `README.md` beside the `lab-status.ps1` row (noting it is hand-maintained rather than a generated launcher), and add a routing row to `AGENTS.md` stating plainly what the two scripts are for: `lab-status.ps1` answers *is this repository ready?* and gates on it, `lab-report.ps1` answers *what does this repository contain?* and never gates.

*Verify:* the commands as written in both documents run verbatim, including under `-ExecutionPolicy Bypass`; `git diff --check` passes; a generated report pasted into a GitHub comment renders with intact tables; the fixture is deleted.

## Verification fixture

Built once under `$env:TEMP` and reused across Steps 1.2–1.5, so no negative test ever touches the developer's real `.claude\skills\` entries:

```powershell
$fixture = Join-Path $env:TEMP "lab-report-fixture"
git clone --no-hardlinks . $fixture
New-Item -ItemType Directory -Path "$fixture\.claude\skills" | Out-Null
Get-ChildItem "$fixture\.agents\skills" -Directory | ForEach-Object {
  New-Item -ItemType Junction -Path "$fixture\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
Copy-Item .\.ai\scripts\lab-report.ps1 "$fixture\.ai\scripts\lab-report.ps1"
```

Junctions need no elevation or Developer Mode, so the fixture reproduces this checkout's real discovery shape. Because the script anchors on `$PSScriptRoot`, the copy inside the fixture reports on the fixture. The fixture is deleted at the final gate.
