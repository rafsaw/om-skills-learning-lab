# Checkpoint 1 — Steps 1.1 through 1.5

**Fired:** 2026-08-15T16:28:00Z (after 5 consecutive Steps)
**Commits covered:** `cd1128b`, `97816df`, `58cea56`, `666fd11`, `1082c03`

## Targeted validation

| Check | Result |
|---|---|
| `git diff --check` (the repository's entire configured gate) | pass — run staged before every one of the five commits |
| `[System.Management.Automation.PSParser]::Tokenize()` over `lab-report.ps1` | pass — 0 parse errors |
| Script runs end to end against the live worktree | pass — exit `0`, all five sections rendered |

There is no compiler, linter, type-checker, or test runner in this repository
(`AGENTS.md` § Validation), so the targeted subset of `validation.commands` is
the whole list. The parse check exists because a PowerShell syntax error would
otherwise ship unnoticed until someone ran the script.

## Fixture-based verification

No test framework exists here, so the spec's verification fixture is the test
procedure. Two scratch clones were built under `$env:TEMP` — never the real
checkout, because a mis-restored `.claude\skills\` entry cannot be recreated on a
machine without symlink privilege. Both are deleted at the final gate.

### Step 1.1 — skeleton and emit path

| Case | Expected | Result |
|---|---|---|
| Bare run | title, generated-at line, five section headings, exit `0` | pass |
| `-Help` | usage, exit `0` | pass |
| `-OutFile` | file written, **no BOM** (first bytes `35 32 111` = `# o`) | pass |
| `-OutFile` content vs stdout | identical apart from the timestamp line | pass |
| `-OutFile` into a missing directory | exit `2`, stderr message, **no directory created** | pass |
| Script copy placed outside the lab | exit `2`, stderr diagnostic, no report | pass |

**Defect found and fixed before the commit:** `if (-not (Write-Report ...))`
captured the function's entire success stream, so the stdout report was swallowed
into the `if` condition — nothing printed while the exit code still said `0`.
Fixed by splitting emission from the file write: `Save-Report` handles files only
and never writes to the success stream, and stdout emission happens inline in
`Invoke-Main` where nothing captures it.

### Step 1.2 — Repository section

| Case | Expected | Result |
|---|---|---|
| Clean tree | `clean` | pass |
| One scratch file | `dirty (1 entry)` | pass |
| Two scratch files | `dirty (2 entries)` — plural agreement | pass |
| Detached HEAD | `(detached at 8da5105)` | pass |
| `git` removed from `PATH` | all four fields `unavailable`, exit `0`, other sections still render | pass |

### Step 1.3 — Installed skills section

| Case | Expected | Result |
|---|---|---|
| Untouched fixture | `18 of 18` resolve, sets match | pass |
| Junction deleted | that row `does not resolve`, count `16 of 18` alongside the next case | pass |
| Junction replaced by a real directory | `does not resolve` | pass |
| Junction whose target was then removed | `does not resolve` | pass |
| Junction repointed at a second clone (the "foreign" case) | `does not resolve`, count `14 of 18` | pass |
| Extra `.claude\skills\` entries with no vendored counterpart | own rows, `-` in the vendored-derived columns | pass |
| `skills-lock.json` truncated to invalid JSON | header says unreadable, Lockfile column `-` on all 18 rows, no crash, exit `0` | pass |

### Step 1.4 — Specs section

| Case | Expected | Result |
|---|---|---|
| Real checkout | specs listed newest-first with dates and real `# ` titles | pass |
| Spec whose only `# ` heading is inside a fence | falls back to the filename stem | pass |
| Filename without a `YYYY-MM-DD` prefix | blank date, row still present | pass |
| `paths.specs` repointed at a nonexistent path | `No specs directory at ...`, note, exit `0` | pass |
| `paths.specs` repointed at an empty directory | `No specs recorded.`, **no** note | pass |

**Defect found and fixed before the commit:** `Get-DocumentTitle -Lines` hit the
same `[string[]]` empty-string binding rejection as Step 1.1 — every document
contains blank lines — so every title silently fell back to the filename stem.
Fixed with `[AllowEmptyString()]`; the real spec titles then read correctly.

### Step 1.5 — Learning artifacts, Summary, escaping

| Case | Expected | Result |
|---|---|---|
| Real counts | 4 experiments / 16 findings with correct latest entries | pass |
| `## Experiment 999` **inside** a fence | ignored — still 4 experiments | pass |
| Same heading **outside** a fence | becomes latest — 5 experiments, latest `999` | pass |
| `FINDINGS.md` deleted | `Not present.`, note, exit `0` | pass |
| Commit subject containing `\|` | escaped, Repository table keeps 2 cells | pass |
| Spec title containing `\|` | escaped, Specs table keeps 3 cells | pass |
| Healthy fixture | ends with `No notes.` | pass |
| Three-way-broken fixture | exactly three notes | pass |

**Two wording defects found and fixed before the commit:** the discovery note read
"1 discovery entry ... **do not** resolve" (verb disagreement, now singular-aware),
and the summary claimed "0 findings" when `FINDINGS.md` was unreadable rather than
empty — a false statement, now rendered as "no readable finding log".

## Integration tests and UI

Skipped, with reason. This repository has **no integration suite** — there is no
application, no test runner, and `validation.commands` is `git diff --check`
alone. The `om-integration-tests` skill is also not installed here, but that is
moot: there would be nothing for it to run. Recorded again at the final gate.

UI verification: **n/a**. The deliverable is a terminal/Markdown document with no
graphical surface, and this repository has no application to drive or screenshot.

## Environment note

The live worktree reports `0 of 18` discovery entries resolving. That is correct,
not a defect: `.claude/` is gitignored and exists only in the primary checkout, so
a linked worktree genuinely has no discovery entries. The report states it plainly
and defers the diagnosis to `lab-status.ps1`, which is exactly the intended
division of labor.
