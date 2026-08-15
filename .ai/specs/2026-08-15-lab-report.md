# Lab report

## 📝 TLDR

`om-skills-learning-lab` can already answer *"can I start a session?"* —
`.ai/scripts/lab-status.ps1` prints a readiness verdict to a terminal and backs
it with an exit code. What it cannot answer is *"what does this lab currently
contain?"*, in a form that survives the terminal: what is installed, what has
been specified, and what the learning log has accumulated. Today that answer is
assembled by hand from `skills-lock.json`, `.agents/skills/`, `.ai/specs/`,
`FINDINGS.md`, and `EXPERIMENTS.md` — five places, re-read every time someone
writes a status update or opens the repository after a gap.

This spec proposes `.ai/scripts/lab-report.ps1`: one read-only Windows
PowerShell script that walks those five sources and emits a **Markdown**
document — repository status, installed skills, available specs, the learning
artifacts, and a short generated summary. It prints to stdout by default and
writes a file with `-OutFile`. It is a *description*, not a gate: it renders no
verdict and never exits non-zero because the lab is in a bad state.

## 📝 Resolved assumptions (autonomous defaults)

This spec was written by `om-auto-write-spec` in autonomous mode. The Open
Questions raised against the skeleton were resolved with the most reversible,
smallest-scope answer available, and every one of them is listed here so a human
can override it before the spec is implemented. None carries
`⚠ NEEDS HUMAN CONFIRMATION`.

| # | Question | Applied default | Why |
|---|----------|-----------------|-----|
| Q1 | Add a Markdown mode to `lab-status.ps1`, or add a separate script? | A separate `.ai/scripts/lab-report.ps1`. `lab-status.ps1` is not touched at all. | The brief asks for "a PowerShell script that generates a Markdown report", which is the literal reading. The two have different jobs — a gate with an exit-code contract versus a descriptive artifact — and keeping them apart means the report cannot regress the readiness check whose section headings and exit codes are already an informal contract. Reversal is deleting one new file. |
| Q2 | Where does the report go? | stdout by default; `-OutFile <path>` writes the file. | stdout keeps the script read-only in its default form, matching the only precedent this repo has. `-OutFile` exists because PowerShell 5.1's `>` redirection writes UTF-16LE, so a caller who wants correct bytes cannot get them by redirecting (see **API Contracts**). |
| Q3 | Is the generated report committed? | No. It is generated output, like everything else under `.ai/analysis/`. | Committing it would put a timestamped, non-deterministic file under version control that re-generates to a diff every run. The script's default (stdout) commits nothing by construction. |
| Q4 | Does the report carry a readiness verdict and a "not ready" exit code? | No. Exit `0` when a report was produced, `2` when one could not be. | Two commands answering the same question with different verdicts is a drift bug waiting to happen. `lab-status.ps1` stays the single authority on readiness; the report describes state and points at it. |
| Q5 | Does the report read remote or tracker state (open PRs, issues, CI)? | No. Local filesystem plus `git` only. | The brief rules out external services explicitly. It also keeps the script fast, offline, and free of a `gh` version dependency. |
| Q6 | Where does the specs directory come from? | `paths.specs` in `.ai/agentic.config.json`, falling back to `.ai/specs` on any read failure. | `paths.specs` *is* the repository's contract for where specs live (protected surface #5); hardcoding it would make the report silently empty if the config ever moved. Reading with a default is the same additive, non-breaking consumption pattern surface #3 blesses. |
| Q7 | How much learning-artifact detail? | Per file: the entry count, the latest entry, and the three most recent entries — headings only, never body text. | Enough to answer "where did the log leave off" without turning the report into a copy of two documents that are already in the repository. |
| Q8 | Does the skills section verify `computedHash` from `skills-lock.json`? | No. Compare the *set* of skill names only. | Re-implementing the `skills` CLI hash in PowerShell would report drift on every local edit, which a learning lab expects to have. This matches the decision already taken for `lab-status.ps1`. |
| Q9 | Does this ship as a skill as well as a script? | No. One script, one phase, no new skill. | A skill adds a name (surface #1), a reference-path tree (#2), and a lockfile question (#7) to deliver output that is deterministic and needs no model reasoning. A skill wrapping the script stays available later and is strictly easier to add once the script exists. |

**Scope cohesion.** Checked, and this brief is one independently deployable
capability: a single script producing a single document. There is nothing here
that would function without the rest, so no split is proposed.

## 📝 Problem Statement

The lab's state is real and it accumulates — 18 vendored skills, a spec
directory, and two learning documents that now hold a double-digit number of
entries between them. But it is **scattered across five sources with no view
that joins them**:

- `.agents/skills/` — what is actually vendored.
- `skills-lock.json` — what the lockfile says is installed, which can disagree.
- `.claude/skills/` — whether any of it is dispatchable in this checkout.
- `.ai/specs/` — what has been designed, whose filenames encode a date but whose
  titles live inside the files.
- `FINDINGS.md` and `EXPERIMENTS.md` — what the lab has established, appended to
  over time, readable only by scrolling to the bottom.

Three concrete situations pay for that:

- **Writing anything about the lab.** A status update, a PR body, a hand-off
  note, or an answer to "what is in this repo?" starts by re-reading the same
  five places and hand-assembling counts that were true five minutes ago.
- **Returning after a gap.** `lab-status.ps1` says the repository is *ready*;
  it does not say what the repository *is*. The reader still has to open
  `EXPERIMENTS.md` and `FINDINGS.md` to reconstruct where the work stopped, and
  `.ai/specs/` to see what was designed but perhaps never implemented.
- **Sharing state off the machine.** The readiness check writes aligned ASCII to
  a console. That is the right shape for a gate and the wrong shape for
  something pasted into a PR comment, an issue, or a document — all of which
  render Markdown.

None of this is a *failure*; nothing breaks. It is friction that repeats every
session, over data that is already fully local and cheap to read. What is
missing is one command that reads all five sources once and renders them into
the format the rest of this repository is written in.

## 📝 Proposed Solution

Add one read-only Windows PowerShell script, `.ai/scripts/lab-report.ps1`:

```console
PS> .\.ai\scripts\lab-report.ps1                                   # print to stdout
PS> .\.ai\scripts\lab-report.ps1 -OutFile .ai\analysis\lab-report.md
```

It reads the repository, renders one Markdown document, and stops. It writes
nothing unless `-OutFile` is given, makes no network call, needs nothing beyond
Windows PowerShell 5.1 and (optionally) `git` on `PATH`, and degrades section by
section rather than failing when something it wanted to read is absent.

### Sample output

````markdown
# om-skills-learning-lab - lab report

Generated 2026-08-15 14:32:10 +02:00 by `.ai/scripts/lab-report.ps1`.

## Repository

| Field | Value |
|---|---|
| Branch | `main` |
| HEAD | `0187454` - feat(skills): add new skill 'om-auto-create-pr-loop' to skills-lock.json |
| Committed | 2026-08-14 |
| Working tree | clean |

## Installed skills

18 vendored under `.agents/skills/`, 18 recorded in `skills-lock.json`, sets match.
18 of 18 discovery entries under `.claude/skills/` resolve into this checkout.

| Skill | SKILL.md | Lockfile | Discovery |
|---|---|---|---|
| `om-approve-merge-pr` | yes | yes | resolves |
| `om-auto-continue-pr` | yes | yes | resolves |
| ... | ... | ... | ... |

## Specs

2 specs under `.ai/specs/`.

| Spec | Date | Title |
|---|---|---|
| `.ai/specs/2026-08-15-lab-report.md` | 2026-08-15 | Lab report |
| `.ai/specs/2026-08-13-lab-status-check.md` | 2026-08-13 | Lab status check |

## Learning artifacts

### FINDINGS.md

11 findings recorded. Latest: 011 - Resumability is built from durable execution
state, not only agent memory.

- 011 - Resumability is built from durable execution state, not only agent memory
- 010 - Approved design is translated into a durable execution artifact before code
- 009 - Spec implementation uses a thin router and a separate execution engine

### EXPERIMENTS.md

4 experiments recorded. Latest: 004 - Autonomous spec implementation lifecycle.

- 004 - Autonomous spec implementation lifecycle
- 003 - Autonomous feature specification lifecycle
- 002 - Autonomous issue orchestration from a plain brief

## Summary

The lab is on branch `main` with a clean working tree. All 18 installed skills
are vendored, recorded in the lockfile, and dispatchable from this checkout.
2 specs are on record, and the learning log holds 4 experiments and 11 findings.

No notes.
````

And a run against a repository in a less tidy state, where the **Summary**
section is what changes:

````markdown
## Summary

The lab is on branch `spec/lab-report` with a dirty working tree (3 entries).
16 of 18 installed skills are dispatchable from this checkout. 2 specs are on
record, and the learning log holds 4 experiments and 11 findings.

Notes:

- The working tree has uncommitted changes, so a report generated now describes
  a state that is not committed anywhere.
- 2 discovery entries under `.claude/skills/` do not resolve into this checkout,
  so those skills dispatch nothing or dispatch another checkout's copy. Run
  `.ai/scripts/lab-status.ps1` for the per-entry diagnosis.
- `skills-lock.json` and `.agents/skills/` disagree on 1 entry.
````

### Alternatives considered

- **A `-Markdown` switch on `lab-status.ps1`.** Rejected (Q1). It would fold a
  descriptive artifact into a gate whose whole value is a narrow, stable
  contract, and the two want different things from the same data: the gate
  classifies (`blocker` / `warning`), the report describes. The switch would
  also inherit the gate's exit-code semantics, so a "not ready" lab would make
  report generation look like it failed.
- **A new `om-lab-report` skill.** Rejected (Q9), for the reason the existing
  spec already recorded for the readiness check: the output is deterministic and
  needs no model reasoning, so paying three protected-surface costs for it is a
  bad trade. A skill that shells out to this script remains available later.
- **Extracting the shared logic into a PowerShell module consumed by both
  scripts.** Rejected *for now* — see **Architecture → Relationship to
  `lab-status.ps1`**. A module is a new surface with its own naming and import
  contract, created to deduplicate roughly forty lines across two consumers.
  The extraction trigger is written down instead.
- **Emitting JSON and rendering Markdown from it.** Rejected: two formats, two
  contracts, and one of them has no consumer. `-Json` is listed as deferred in
  **Phasing** so a later reader knows it was considered.

## 📝 Architecture

One file. `.ai/scripts/lab-report.ps1`, `#Requires -Version 5.1`, sourcing
nothing else in the repository.

```text
lab-report.ps1
├── anchor ................ repo root from $PSScriptRoot; verify it is this lab
├── collect ............... five readers, each returning a plain object
│   ├── repository ........ git: branch, HEAD sha/subject/date, porcelain status
│   ├── skills ............ .agents/skills/, skills-lock.json, .claude/skills/
│   ├── specs ............. ${SPECS_DIR}/*.md -> filename date + H1 title
│   └── learning log ...... EXPERIMENTS.md + FINDINGS.md heading scan
├── render ................ collected objects -> Markdown lines (no I/O)
└── emit .................. stdout, or -OutFile as UTF-8 without BOM
```

**Collect and render are separate.** Every reader returns data; nothing in a
reader writes a line of Markdown. This is not architecture for its own sake: it
is what makes the escaping rule below enforceable in one place, and what makes a
later `-Json` mode (deferred) a new renderer rather than a rewrite.

**Anchoring — the script locates the repository, not the caller.** The root is
derived from `$PSScriptRoot` (`<root>\.ai\scripts`, so the root is two levels
up), never from the current directory and never from `git rev-parse
--show-toplevel` against the caller's `cwd`. Running the script by absolute path
from inside an unrelated repository must not produce a confident report about
that repository. The script then confirms the anchored root is this lab by
requiring both `.agents\skills\` and `.ai\agentic.config.json` to exist; if
either is missing it writes a diagnostic to stderr and exits `2` without
emitting a report. This is deliberately identical to `lab-status.ps1`: two
scripts in the same directory that disagree about what "the repository" means
would be worse than the duplication.

**Boundaries.** The script reads the repository, invokes `git` for three facts
(branch, HEAD description, working-tree status), and reads
`.ai/agentic.config.json` for exactly one value (`paths.specs`, with a default).
It writes to stdout and stderr, and to the single path given by `-OutFile`. It
never writes `skills-lock.json` (surface #7), never repairs a discovery entry
(surface #6), and never touches anything under `.agents/skills/`.

### Relationship to `lab-status.ps1`

The two scripts overlap on three readers: the git branch/status probe, the
skill-discovery resolution check, and the fenced-heading scan of the learning
log. That overlap is **accepted and bounded**, and the reasoning is recorded
here so a reviewer does not have to reconstruct it:

- The overlap is roughly forty lines of small, stable helpers over file formats
  that are themselves stable (a porcelain status line, an NTFS link target, a
  Markdown heading).
- The two consumers want different *outputs* from the same reads. The gate needs
  a five-way classification (`ok` / `missing` / `not-a-link` / `broken` /
  `foreign`) because each class implies a different repair. The report needs one
  bit — *does this resolve into this checkout?* — because it does not propose
  repairs; it points at the gate. Sharing the code would mean sharing the
  five-way classification into a consumer that immediately collapses it.
- A shared module is a new import contract and a new name in a repository whose
  documented failure mode is exactly "something resolves a name that moved"
  (`BACKWARD_COMPATIBILITY.md`).

**Extraction trigger, written down so it is not a matter of taste:** when a
*third* consumer of any of these readers appears, or when either script needs a
change to a shared reader that the other must match, extract
`.ai/scripts/lab-common.ps1` in that same change and convert both callers. Until
then, duplication is the cheaper coupling.

**What must not diverge.** Three behaviors are copied deliberately and must stay
identical in both scripts; a change to one is a change to both:

1. The anchor rule (`$PSScriptRoot` two levels up, `.agents\skills\` plus
   `.ai\agentic.config.json`) and its exit code `2`.
2. Accepting **both** `SymbolicLink` and `Junction` as valid discovery link
   types. The entries in this checkout are junctions — Git Bash on Windows
   without symlink privilege produces them, and every repository document
   nonetheless calls them symlinks. A check demanding `SymbolicLink` reports a
   perfectly healthy lab as entirely broken.
3. Comparing link targets only after normalizing both sides with
   `[System.IO.Path]::GetFullPath()`, case-insensitively, so drive-letter
   casing, a trailing separator, or a `..` segment cannot manufacture a false
   negative.

### Section readers

**Repository.** Three `git` calls, each run with `-C $RepoRoot` so the caller's
directory is irrelevant: the branch (via `symbolic-ref --short HEAD`, falling
back to a short SHA on a detached HEAD), the HEAD description (`log -1
--format=%h|%s|%ad --date=short`, split on a delimiter that cannot occur in a
short SHA or an ISO date), and `status --porcelain` for the entry count. When
`git` is absent or the root is not a work tree, every field renders as
`unavailable` and the section prints anyway.

**Installed skills.** Directories under `.agents\skills\` are the spine. Per
skill: does it contain a `SKILL.md` (a directory without one is not
dispatchable); is its name present in `skills-lock.json`; and does
`.claude\skills\<name>` resolve to this repository's `.agents\skills\<name>`. A
name appearing in the lockfile or in `.claude\skills\` but **not** under
`.agents\skills\` gets its own row with `-` in the vendored-derived columns, so
the table never silently omits something that exists.

**Specs.** Every `*.md` directly under `${SPECS_DIR}` (no recursion — the
directory is flat by convention, and `assets/` subdirectories hold mockups, not
specs). The date comes from a leading `YYYY-MM-DD` in the filename when present
and is blank otherwise; the title is the first `# ` heading found **outside a
code fence**, falling back to the filename stem. Sorted newest first by filename
descending, which for the `YYYY-MM-DD-` convention is chronological.

**Learning artifacts.** `EXPERIMENTS.md` and `FINDINGS.md` are scanned line by
line with fence tracking, matching `^##\s+(Experiment|Finding)\s+(\d{3})\b`
outside fences only, exactly as `lab-status.ps1` does and for the same reason:
`EXPERIMENTS.md` carries an entry template inside a fenced block whose heading is
`## Experiment NNN`, and a digit-anchored pattern skips it today only because the
placeholder is literally `NNN`. Entries are collected, de-duplicated by number
(highest wins), sorted descending, and the top three are listed.

**Summary.** Generated from the collected data, never hand-written: one prose
paragraph naming the branch, the working-tree state, the dispatchable-skill
count, the spec count, and the two log counts. Below it, a `Notes:` list that is
**present only when something is off** — a dirty tree, an unresolved discovery
entry, lockfile drift, or a degraded section — each note one sentence, and the
discovery note pointing at `.ai/scripts/lab-status.ps1` rather than restating
its diagnosis. With nothing off, the section ends with `No notes.`

### Markdown correctness

The output is a document that other tools render, so three rules are structural
rather than cosmetic:

- **Every interpolated value is escaped for the context it lands in.** A commit
  subject, a spec title, or a finding heading can legally contain `|`, which
  ends a table cell, or a backtick, which opens a code span. Values entering a
  table cell have `|` replaced with `\|`; values entering a code span with
  backticks in them are rendered as plain text instead. This happens in the
  renderer, which is why collect and render are separate.
- **Paths are plain repo-relative text in backticks, never Markdown links.** The
  report can be written anywhere (`-OutFile` takes an arbitrary path) and is
  meant to be pasted into PR comments and issues, so a relative link would
  resolve correctly in approximately none of those places. Not linking is the
  only option that is never wrong.
- **Forward slashes in every printed path**, including on Windows. The document
  is read as Markdown far more often than it is pasted into a shell, and
  backslashes inside backticks read as escapes to some renderers.

## 📝 Data Model

No persistent state: no cache, no history file, no database, and no write other
than the optional `-OutFile`. The script's data is in-memory, and exists only
between collect and render:

| Name | Shape | Purpose |
|---|---|---|
| `$RepoRoot` | path | Anchor for every relative path, derived from `$PSScriptRoot`. |
| `$SpecsDir` | path | `paths.specs` from the config, or `.ai/specs` when unreadable. |
| `$Repository` | object | `Branch`, `Sha`, `Subject`, `Date`, `Dirty` (int or `$null`), `Available` (bool). |
| `$Skills` | object[] | One per row: `Name`, `Vendored`, `HasSkillMd`, `InLock`, `Discovery` (`resolves` / `does not resolve` / `-`). |
| `$Specs` | object[] | `Path` (repo-relative), `Date`, `Title`. |
| `$Log` | object[] | Per document: `File`, `Count`, `Latest`, `Recent` (up to three `Number` + `Title` pairs). |
| `$Notes` | string[] | Summary notes, each a full sentence; empty when nothing is off. |

**Sensitive data: none in scope, and one rule to keep it that way.** The script
prints a branch name, a commit subject, counts, skill names, spec titles, and
log headings. It must not print environment variables, the contents of
`.ai/agentic.config.json` beyond the single `paths.specs` value it consumes, or
the body of any file it scans. The commit subject is the one field sourced from
free text a human wrote; it is escaped (above) but not filtered, on the
reasoning that a commit subject is already public in the git history the report
describes.

## 📝 API Contracts

The script's contract is its command line, its exit code, and — loosely — the
Markdown heading structure it emits.

**Invocation.**

```text
.ai\scripts\lab-report.ps1 [-OutFile <path>] [-Help]
```

`-Help` prints usage to stdout and exits `0`. An unsupported parameter is
rejected by PowerShell's own parameter binding before the script body runs; as
with `lab-status.ps1`, that failure surfaces as a binding **error** under direct
invocation (where `$LASTEXITCODE` is meaningless and must not be read) and as an
unspecified non-zero exit under `powershell -File`. Because this repository
ships no execution-policy configuration, the documented invocation for a
restricted machine is
`powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-report.ps1`.

**Exit codes.** Deliberately two, because the report renders no verdict:

| Code | Meaning |
|---|---|
| `0` | A report was produced. Says nothing about whether the lab is healthy — that is `lab-status.ps1`'s question. Also the successful `-Help` exit. |
| `2` | No report could be produced: the anchored root is not this lab, or `-OutFile` could not be written. Both are reported on stderr. |

A caller wanting readiness runs `lab-status.ps1` and reads *its* exit code. A
caller wanting the document runs this and treats any non-zero as "no document".

**Encoding — the trap this contract exists to route around.** Windows PowerShell
5.1 writes UTF-16LE when a command's output is redirected with `>`, so

```powershell
.\.ai\scripts\lab-report.ps1 > report.md     # UTF-16LE. Wrong bytes.
```

produces a file that git treats as binary and most Markdown renderers refuse.
`-OutFile` exists for exactly this reason and writes **UTF-8 without a BOM** via
`[System.IO.File]::WriteAllText` with a `UTF8Encoding($false)` — not
`Set-Content -Encoding UTF8`, which in 5.1 emits a BOM. That matches every other
file in this repository. stdout is for reading and piping to a pager; `-OutFile`
is for producing the artifact, and `-Help` says so in one line.

Input decoding has the mirror-image trap: `Get-Content` without `-Encoding UTF8`
decodes with the host's ANSI code page in 5.1, so an em dash in a finding
heading arrives as mojibake on a `cp1252` host. Every file this script reads is
read with `-Encoding UTF8` explicitly.

**Output shape.** A Markdown document with a level-1 title, a generated-at line,
and five level-2 sections in a fixed order: `Repository`, `Installed skills`,
`Specs`, `Learning artifacts`, `Summary`. The heading text is stable enough to
grep for and this spec declares it an **informal contract** — the same status
`lab-status.ps1`'s section headings carry. It is deliberately not promoted to a
protected surface: nothing consumes it yet, and adding a ninth surface for a
convenience script would cheapen the list. Changing a heading later is a rename
another script could be resolving, so by `BACKWARD_COMPATIBILITY.md` §
"Deciding whether a change is breaking" it gets called out in the PR body.

**Determinism.** Every part of the output is a pure function of the repository
state **except** the generated-at line, which is why Q3 answers "not committed":
a committed report would re-generate to a diff on every run. A future caller
that wants byte-stable output diffs everything below the generated-at line.

## 📝 UI/UX

The interface is the Markdown document shown under **Proposed Solution**, and it
is designed for three destinations at once — a terminal, a rendered Markdown
preview, and a pasted PR or issue comment. Four constraints follow:

- **Readable as source, not only as rendered output.** Tables stay narrow enough
  to scan unrendered, prose is wrapped, and no section depends on rendering to
  make sense. The most common way this document will be read is in a terminal,
  as plain text.
- **Tables for enumerations, prose for the summary.** Skills and specs are
  lists of like things and belong in tables. The summary is a judgement about
  the whole and belongs in a sentence, because that is the part a human copies
  into an update.
- **Notes appear only when there is something to note.** A permanently present
  "Notes: none" trains the reader to skip the section that matters. `No notes.`
  is the one-line healthy state; a populated `Notes:` list is a signal.
- **No emoji, no color, no box drawing.** The repository's own documents use
  emoji in spec headings, but this is generated output that lands in log
  captures, agent transcripts, and a Windows console whose default code page
  mangles non-ASCII. Non-ASCII characters *lifted from the repository* — an em
  dash in a finding title — are preserved, because the file output is UTF-8 and
  losing them would corrupt the data the report exists to carry.

No mockups or screenshots accompany this spec. The feature has no graphical
surface and this repository has no application to screenshot; the sample output
blocks under **Proposed Solution** are the visual specification.

## 📝 Edge Cases & Failure Scenarios

| Scenario | Behavior |
|---|---|
| Run from a subdirectory, or with `cwd` inside an unrelated repository | Unaffected: the root comes from `$PSScriptRoot`. The report always describes the repository the script lives in. |
| A copy of the script placed outside this lab | Anchor check fails, stderr diagnostic, exit `2`, no output. |
| `git` absent, or the root is not a work tree | Every Repository field renders `unavailable`; a note says so; the other four sections are unaffected and the exit code stays `0`. |
| Detached HEAD | Branch renders as `(detached at <sha>)`. |
| Unborn branch (a repository with no commits) | Branch resolves via `symbolic-ref`; HEAD fields render `unavailable` with a note. |
| A commit subject containing `|` or a backtick | Escaped by the renderer; the table does not break. This is the realistic escaping case, since commit subjects are free text. |
| `.ai/agentic.config.json` unreadable or missing `paths.specs` | Falls back to `.ai/specs` silently — the anchor check already guarantees the file exists, so a parse failure here is degradation, not a wrong context. |
| `paths.specs` points somewhere that does not exist | Specs section prints `No specs directory at <path>.`; one note; exit `0`. |
| Specs directory empty | `No specs recorded.`; no note — an empty spec directory is a normal early state, not a problem. |
| A spec file with no `# ` heading, or whose only heading is inside a fence | Title falls back to the filename stem. |
| A spec filename without a leading `YYYY-MM-DD` | Date cell is blank; the row still appears, sorted by filename. |
| `.claude\skills\` missing entirely (fresh clone) | Every Discovery cell reads `does not resolve`; one note pointing at `lab-status.ps1` and `README.md` § Start here. Still exit `0` — describing a broken lab is a successful report. |
| A discovery entry is a junction rather than a symbolic link | `resolves`. Both link types are accepted; this is the normal state of this checkout. |
| A discovery entry is a real directory, is broken, or points at another checkout | `does not resolve` in all three cases. The report does not distinguish them; `lab-status.ps1` does, and the note says to run it. |
| A name in `skills-lock.json` or `.claude\skills\` with nothing under `.agents\skills\` | Gets its own row with `-` in the columns that need a vendored directory, so nothing is silently dropped. |
| `skills-lock.json` missing or malformed | Lockfile column reads `-` for every row, the header line says the lockfile is unreadable, one note; `ConvertFrom-Json` failure is caught and never fatal. |
| `EXPERIMENTS.md` or `FINDINGS.md` missing, empty, or template-only | `No entries recorded.` for that document plus one note. |
| A heading such as `## Experiment 003` inside a fenced block | Ignored. Fence tracking excludes it, so a documentation example cannot become a phantom entry. |
| Two entries with the same number | De-duplicated by number, highest-numbered wins, no crash. |
| `-OutFile` in a directory that does not exist | stderr message naming the path, exit `2`. The script does not create directories — silently creating a tree from a typo'd path is worse than failing. |
| `-OutFile` pointing at an existing file | Overwritten without prompting. It is a generated artifact; the spec recommends writing under `.ai/analysis/`, which `AGENTS.md` already documents as generated-not-source. |
| `-OutFile` not writable (locked, read-only, permission denied) | Caught, stderr message, exit `2`. Nothing is half-written: the document is rendered fully in memory and written in one call. |
| Output redirected with `>` instead of `-OutFile` | Produces UTF-16LE in PowerShell 5.1. Documented in `-Help` and **API Contracts**; the script cannot detect or prevent it. |
| Script run twice concurrently with the same `-OutFile` | Last writer wins. Both reads are safe; concurrent identical writes are not worth a lock for a generated report. |

## 📝 Risks & Impact Review

**Blast radius: near zero.** The change adds one new file under `.ai/scripts/`
and short pointers in two documents. It touches no skill, no descriptor, no
configuration, and — deliberately — not `lab-status.ps1`. Nothing in the
pipeline dispatches to it, so a bug in it cannot fail a PR, a review, or a
merge. The worst outcome is a wrong report on a terminal, or a wrongly-encoded
file at a path the caller chose.

**Protected surfaces** (`BACKWARD_COMPATIBILITY.md`):

- **#5, directory contract under `.ai/`** — respected. The script lands in
  `paths.scripts`, which the repository already commits, and it *reads*
  `paths.specs` rather than hardcoding a second copy of it.
- **#3, `.ai/agentic.config.json` schema** — this script becomes a new **reader**
  of one field, `paths.specs`, with a documented default. That is the additive,
  read-with-default pattern the surface explicitly blesses as non-breaking, and
  it is the reason the fallback exists: a config that omits or moves the key
  degrades the script rather than breaking it. It reads no other field and
  writes nothing.
- **#1 skill names, #2 reference paths, #7 `skills-lock.json`** — untouched. The
  script reads the lockfile and must never write it, and it must never rename or
  create a skill directory.
- **#6 discovery entries** — reported on, never repaired. Repair stays the
  deliberate human step the document says it is.
- No new protected surface is created. The Markdown heading structure and the
  two exit codes are documented as an informal contract in **API Contracts**.

**Risks:**

1. *Duplication with `lab-status.ps1` drifting.* Two scripts read the same three
   things. If one is fixed and the other is not, they can disagree about the
   same repository, which is worse than either being wrong alone. Mitigated by
   naming the three must-not-diverge behaviors explicitly in **Architecture**,
   by writing down the extraction trigger, and by the report deferring every
   discovery *diagnosis* to `lab-status.ps1` rather than restating it.
2. *A report that is trusted more than it should be.* The document looks
   authoritative and is a snapshot of a moment — and, on a dirty tree, a
   snapshot of uncommitted state. Mitigated by the generated-at line, by the
   dirty-tree note saying exactly that, and by the report rendering no verdict
   so it cannot be mistaken for a gate.
3. *No PowerShell linting in this repository.* The validation gate is
   `git diff --check`; a syntax error would ship unnoticed until someone ran the
   script. Mitigated by the fixture in the implementation plan, and by parsing
   the file with `[System.Management.Automation.PSParser]::Tokenize()` as an
   explicit check in Step 1 — the same mitigation the readiness-check spec used.
4. *PowerShell 5.1 only.* `pwsh` is not installed on the development machine, so
   the script targets Windows PowerShell 5.1 and must avoid 7.x syntax (`??`,
   ternaries, `ConvertFrom-Json -AsHashtable`). `#Requires -Version 5.1` states
   the floor; a 7.x host runs it unchanged. The encoding behaviors this spec
   routes around (`>` redirection, `Set-Content -Encoding UTF8`, `Get-Content`
   default decoding) are 5.1-specific and the reason the file write is done
   through `[System.IO.File]::WriteAllText`, which behaves identically on both.
5. *Malformed Markdown from unescaped repository text.* A single `|` in a commit
   subject or spec title breaks a table for every downstream reader. Mitigated
   by centralizing escaping in the renderer and by testing it explicitly in
   Step 5's verification.

**Rollback:** delete `.ai/scripts/lab-report.ps1` and revert the documentation
pointers added in Step 6. There is no state, no migration, and no programmatic
consumer, so a revert is complete by construction.

## 📋 Phasing

**Phase 1 — the report.** Everything in this spec: the five sections, the
generated summary, `-OutFile`, `-Help`, the two exit codes, and the
documentation pointers that make it discoverable. Independently shippable and
complete on its own.

**Phase 2 (deferred, not part of this spec)** — recorded so a later reader knows
these were considered and why they are absent: a `-Json` mode (no consumer yet);
tracker and remote state such as open PRs, issue counts, and CI status (Q5 — the
brief rules out external services, and it would add a `gh` version dependency);
git ahead/behind against the upstream; `computedHash` verification (Q8);
per-spec implementation status; a `-Since` filter over the learning log; a
byte-stable mode that omits the generated-at line for diffing two reports; and an
`om-lab-report` skill wrapping the script (Q9). None is started until something
concretely needs it.

## 📋 Implementation Plan

Each step leaves the repository in a working state — trivially true here, since
until Step 6 the script is a new file nothing references.

### Verification fixture

Steps 3–5 need a repository in states this checkout must not be put into. In
particular **no step may touch the developer's real `.claude\skills\` entries**:
on a machine without symlink privilege a mis-restored entry cannot simply be
recreated. Every negative test therefore runs against a **scratch clone** built
outside the repository and reused across steps:

```powershell
$fixture = Join-Path $env:TEMP "lab-report-fixture"
git clone --no-hardlinks . $fixture
New-Item -ItemType Directory -Path "$fixture\.claude\skills" | Out-Null
Get-ChildItem "$fixture\.agents\skills" -Directory | ForEach-Object {
  New-Item -ItemType Junction -Path "$fixture\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
Copy-Item .\.ai\scripts\lab-report.ps1 "$fixture\.ai\scripts\lab-report.ps1"
```

Junctions need no elevation or Developer Mode, so the fixture reproduces this
checkout's real discovery shape. Because the script anchors on `$PSScriptRoot`,
the copy inside the fixture reports on the fixture. Delete the fixture when the
plan is done; it lives under `$env:TEMP`, never inside the repository.

### Phase 1

1. **Create the script skeleton and the emit path.** Add
   `.ai/scripts/lab-report.ps1` with `#Requires -Version 5.1`,
   `Set-StrictMode -Version Latest`, `[string]$OutFile` and `[switch]$Help`
   parameters, usage text, root resolution from `$PSScriptRoot` with the
   `.agents\skills\` + `.ai\agentic.config.json` anchor check and exit `2`, the
   `$SpecsDir` resolution (read `paths.specs` inside a `try`, fall back to
   `.ai/specs`), the collect/render split as empty functions, and the emit
   function writing either to stdout or to `-OutFile` via
   `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`.
   *Verify:* the script emits the title, the generated-at line, and five empty
   section headings, and exits `0`; `-Help` prints usage and exits `0`;
   `-OutFile` produces a file whose first bytes are **not** a BOM and whose
   content matches stdout byte-for-byte apart from the line ending; `-OutFile`
   into a nonexistent directory exits `2` with a stderr message and creates
   nothing; a copy of the script placed outside the lab exits exactly `2` with a
   stderr diagnostic and no output;
   `[System.Management.Automation.PSParser]::Tokenize()` over the file reports no
   parse errors.
2. **Implement the Repository section.** Branch, HEAD sha/subject/date, and
   working-tree entry count, each via `git -C $RepoRoot`. Render the four-row
   table, degrade every field to `unavailable` with a note when `git` is missing
   or the root is not a work tree, and add the dirty-tree note.
   *Verify:* the real checkout renders its branch, HEAD, and `clean`; after
   creating a scratch file in the fixture the table says `dirty (1 entry)` and
   the dirty note appears with exit `0`; with `git` removed from `PATH` for one
   invocation every field reads `unavailable`, the note appears, and the other
   sections still render; a detached HEAD in the fixture renders
   `(detached at <sha>)`.
3. **Implement the Installed skills section.** Enumerate `.agents\skills\`, read
   `skills-lock.json` inside a `try`, enumerate `.claude\skills\` once (a
   listing includes a link whose target no longer exists, which a `Test-Path`
   probe would not), and classify each discovery entry as `resolves` /
   `does not resolve` — accepting both `SymbolicLink` and `Junction`, comparing
   targets through `GetFullPath()` case-insensitively. Emit the header counts,
   the four-column table including rows for lockfile-only and discovery-only
   names, and the discovery and lockfile-drift notes.
   *Verify (all in the fixture, never in the real checkout):* the untouched
   fixture reports every skill as `resolves` with matching sets; deleting one
   junction flips that row to `does not resolve` and adds the note, with exit
   `0`; replacing one junction with a real directory, breaking a junction's
   target, and repointing one at a second clone each also yield
   `does not resolve`; adding `.claude\skills\om-ghost` produces its own row;
   truncating `skills-lock.json` to invalid JSON makes the Lockfile column `-`
   for every row, adds the note, and does not crash.
4. **Implement the Specs section.** Enumerate `*.md` directly under
   `$SpecsDir`, parse the leading `YYYY-MM-DD` from each filename, read the
   first `# ` heading outside a code fence for the title (falling back to the
   filename stem), sort newest first, and render the table with repo-relative
   forward-slash paths. Handle the missing-directory and empty-directory cases.
   *Verify:* the real checkout lists the existing specs with their titles and
   dates; a spec whose only `# ` heading sits inside a fenced block falls back
   to the filename stem; a file named without a date prefix renders with a blank
   date and still appears; pointing `paths.specs` at a nonexistent path in the
   fixture's config prints the missing-directory line plus a note with exit `0`;
   an empty specs directory prints `No specs recorded.` with no note.
5. **Implement the Learning artifacts section, the Summary, and escaping.** Scan
   `EXPERIMENTS.md` and `FINDINGS.md` with fence tracking and the
   `^##\s+(Experiment|Finding)\s+(\d{3})\b` pattern, de-duplicate by number,
   render the count, the latest entry, and the three most recent. Then generate
   the summary paragraph from the collected data and emit the `Notes:` list —
   or `No notes.` Finally, route **every** interpolated value through the
   table-cell and code-span escaping helpers described in **Architecture →
   Markdown correctness**.
   *Verify:* the real checkout reports the correct experiment and finding counts
   and the correct latest entry for each; a `## Experiment 999` heading added
   *inside* a fenced block in the fixture changes nothing, while the same
   heading outside a fence becomes the latest; deleting `FINDINGS.md` in the
   fixture prints `No entries recorded.` plus a note with exit `0`; a fixture
   commit whose subject contains `|` and a spec title containing `|` both render
   without breaking their tables; a healthy fixture ends with `No notes.` and a
   fixture broken in three ways lists exactly three notes.
6. **Make it discoverable.** Add `.ai/scripts/lab-report.ps1` to the repository
   map in `README.md` beside the `lab-status.ps1` row (noting, as that row does,
   that it is hand-maintained rather than a generated launcher), and add a
   routing row to `AGENTS.md` — "summarizing the current state of the lab" —
   that states plainly what the two scripts are for: `lab-status.ps1` answers
   *is this repository ready?* and gates on it, `lab-report.ps1` answers *what
   does this repository contain?* and never gates. Keep both edits to a few
   lines; `-Help` is the reference, the docs are the pointer.
   *Verify:* the commands as written in `README.md` and `AGENTS.md` run
   verbatim, including under `-ExecutionPolicy Bypass`; `git diff --check`
   passes; a generated report pasted into a GitHub comment renders with intact
   tables; the fixture is deleted.

### Out of scope for this plan

No changes to `.ai/scripts/lab-status.ps1`, to any file under `.agents/skills/`,
`.ai/trackers/`, or `.ai/browsers/`, to `.ai/agentic.config.json`, or to the
`.claude/skills/` entries of the working checkout. If implementing this appears
to require one, that is a signal the design drifted and the spec should be
amended first.
