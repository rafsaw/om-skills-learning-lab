# Lab status check

## 📝 TLDR

`om-skills-learning-lab` has no build system, so there is no `npm start` that
fails loudly when the repository is not usable. The one thing that genuinely
stops a learning session — a `.claude/skills/` discovery entry that is missing,
broken, or resolving to something other than this repository's
`.agents/skills/<name>` — fails quietly, at the moment a skill is dispatched
rather than at the moment the repository is opened. This spec proposes
`.ai/scripts/lab-status.ps1`: one read-only Windows PowerShell script that
answers "is this repo ready for the next learning session?" in a couple of
seconds, printing the branch and working-tree state, skill-discovery health, and
the latest recorded experiment and finding, then a `READY` / `NOT READY` verdict
backed by its exit code.

## 📝 Revision history

- **2026-08-13, initial draft** — written by `om-auto-write-spec` in autonomous
  mode; Open Questions Q1–Q7 resolved by autonomous default.
- **2026-08-13, amendment (this revision)** — rewritten after an architectural
  review and a human decision pass. Two things changed: the implementation
  language is now Windows PowerShell rather than POSIX `sh`, and Phase 1 is cut
  down to the smallest useful status report. The review findings that survive
  the reduction are folded in; the ones that only applied to deferred checks are
  gone with them (see **Resolved decisions**).

## 📝 Resolved decisions

The autonomous defaults from the first draft are superseded by the human
decisions below. Every prior question is listed so the audit trail survives the
rewrite.

| # | Question | Decision | Status vs. first draft |
|---|----------|----------|------------------------|
| D1 | Shell or skill? | A single script, `.ai/scripts/lab-status.ps1`. No new skill. | Unchanged. `.ai/scripts/` is the committed script home (protected surface #5); a skill would add a name (#1), reference paths (#2), and a lockfile question (#7) for a deterministic report. |
| D2 | Which language? | **Windows PowerShell 5.1**, not POSIX `sh`. | **Changed by decision.** The primary workflow for this lab is Windows + PowerShell; `pwsh` is not installed on the development machine, so the script targets 5.1 and avoids PowerShell 7 syntax. |
| D3 | Local or remote state? | Local state only. No network call, no tracker read. | Unchanged, and now stronger: with the toolchain checks deferred there is nothing in Phase 1 that touches `gh` at all. |
| D4 | Output format? | Human-readable text only. `--json` deferred. | Unchanged. |
| D5 | Exit code semantics? | `0` ready, `1` at least one blocker, `2` misuse or wrong context. | Unchanged. |
| D6 | Verify vendored-skill integrity by recomputing `computedHash`? | No. Compare only the *set* of skill names in `skills-lock.json` against the directories under `.agents/skills/`. | Unchanged. Reimplementing the `skills` CLI hash in PowerShell would produce false drift on every local edit, which a learning lab expects to have. |
| D7 | Should the script repair what it finds? | No. Strictly read-only. It names the problem and points at `README.md` § Start here for the recreation snippet. | Unchanged, with the remediation text simplified: per-finding fix commands are deferred (D9). |
| D8 | One capability, or several? | One report, one script, one phase. | Unchanged. |
| D9 | How much belongs in Phase 1? | Only the checks that genuinely stop the next session: branch and working-tree state, skill discovery (count, per-entry resolution, lockfile set), and the latest experiment and finding. | **Changed by decision.** The first draft also specified `gh` and `jq` version checks, upstream ahead/behind, a `git diff --check` validation gate, active-worktree diagnostics, and per-finding remediation commands. All are deferred to Phase 2. |

## 📝 Problem Statement

This repository is Markdown that an agent executes, with no compiler, linter, or
test runner (`AGENTS.md` § Validation). That has a specific consequence: **every
readiness problem here fails silently and late.** The failure surfaces as a skill
that does not dispatch, or an agent that reads a file from somewhere other than
this checkout, rather than as a build error.

The failure modes this repository already documents, narrowed to the ones Phase 1
answers:

- **Skill discovery is missing after a clone.** `.claude/` is gitignored, so a
  fresh clone contains `.agents/skills/` but nothing that dispatches to it
  (`README.md` § Start here). The symptom is "the skill doesn't exist", with no
  error pointing at the discovery entries.
- **A discovery entry exists but does not lead to this repository's skill.** It
  may be a real directory instead of a link — a Windows accident when the
  recreation snippet runs without the privilege to create links — or a link
  whose target resolves into a *different* checkout. Both are protected surface
  #6 in `BACKWARD_COMPATIBILITY.md`: the skill has forked into two sources that
  then drift. Nothing reports it; the agent simply executes instructions that
  are not the ones in this working tree. **This is the single check the script
  exists for**, and the one an "does `.claude/skills/om-fix` exist?" test misses.
- **The vendored set and the lockfile disagree.** A skill added or removed
  without the `skills` CLI leaves `skills-lock.json` describing an install that
  no longer matches the tree, so the next reproducible install is wrong.
- **The working tree is dirty.** A session that starts on top of uncommitted
  edits produces a PR containing work nobody meant to ship.
- **Nobody remembers where the learning log left off.** `EXPERIMENTS.md` and
  `FINDINGS.md` are the record of what this lab has established, and the next
  session normally continues from the last entry — which currently means opening
  two files and scrolling to the bottom of each.

Every one of these is answerable from the local filesystem in well under a
second. What is missing is a single place that asks all of them at once.

## 📝 Proposed Solution

Add one read-only Windows PowerShell script, `.ai/scripts/lab-status.ps1`:

```console
PS> .\.ai\scripts\lab-status.ps1
```

It performs three groups of checks, prints one section per group, and ends with a
verdict. It never writes to the repository, never makes a network call, and needs
nothing beyond Windows PowerShell 5.1 and `git` on `PATH` — and it degrades
rather than failing when `git` is absent.

### Sample output

```text
om-skills-learning-lab - status

Repository
  Branch            spec/lab-status-check
  Working tree      clean

Skills
  Vendored          13 under .agents/skills/
  Discovery         13 of 13 resolve into this repository
  Lockfile          13 entries, matching

Learning log
  Latest experiment 002 - Autonomous issue orchestration from a plain brief
  Latest finding    005 - Issue orchestration is explicit and resumable

READY - no blockers found.
```

And a failing run, which is the case the script exists for:

```text
Skills
  Vendored          13 under .agents/skills/
  Discovery         11 of 13 resolve into this repository
                    missing:  om-fix
                    foreign:  om-root-cause -> C:\old-clone\.agents\skills\om-root-cause
  Lockfile          13 entries, matching

Learning log
  Latest experiment 002 - Autonomous issue orchestration from a plain brief
  Latest finding    005 - Issue orchestration is explicit and resumable

NOT READY - 2 blockers, 1 warning.

  [blocker] om-fix has no .claude\skills entry and cannot be dispatched.
  [blocker] om-root-cause resolves outside this repository, so dispatching it
            executes a different checkout's copy of the skill.
  [warning] Working tree is dirty (3 entries).

  Discovery entries are recreated by the snippet in README.md, "Start here".
```

### Alternatives considered

- **A new `om-lab-status` skill.** Rejected as the primary form: it adds a skill
  name, a reference-path tree, and a `skills-lock.json` question (protected
  surfaces #1, #2, #7) to deliver a report that is deterministic and needs no
  model reasoning. A skill that shells out to this script remains available
  later, and is strictly easier to add once the script exists.
- **A POSIX `sh` script run under Git Bash.** Rejected by decision D2: the
  primary workflow here is Windows and PowerShell, and PowerShell reads the two
  things the script most needs — a link's `LinkType` and `Target`, and
  `skills-lock.json` via `ConvertFrom-Json` — natively, where the shell version
  needed `readlink` plus `jq`.
- **Extending `om-setup-agent-pipeline` with a `--check` mode.** Rejected: that
  skill is the setup *authority* and is expected to write files; folding a
  read-only check into it blurs a boundary this repo deliberately keeps sharp,
  and it is a vendored skill, so editing it in place drifts its lockfile hash.

## 📝 Architecture

One file. `.ai/scripts/lab-status.ps1`, `#Requires -Version 5.1`, sourcing
nothing else in the repo.

```text
lab-status.ps1
├── anchor ...................... repo root from $PSScriptRoot; verify it is this lab
├── section: Repository ......... branch + working-tree state (git)
├── section: Skills ............. vendored / discovery resolution / lockfile set
├── section: Learning log ....... EXPERIMENTS.md + FINDINGS.md heading scan
└── verdict ..................... collected blockers/warnings -> text + exit code
```

**Anchoring — the script locates the repository, not the caller.** The root is
derived from the script's own location (`$PSScriptRoot` is `<root>\.ai\scripts`,
so the root is two levels up), never from the current directory and never from
`git rev-parse --show-toplevel` against the caller's `cwd`. Running the script by
absolute path from inside an unrelated repository must not produce a confident
report about that repository. The script then confirms the anchored root is this
lab by requiring both `.agents\skills\` and `.ai\agentic.config.json` to exist;
if either is missing it writes a diagnostic to stderr and exits `2` without
printing a report.

**Boundaries.** The script reads the repository and invokes `git` for two facts
(current branch, working-tree status). It writes only to stdout and stderr. It
does not read `.ai/agentic.config.json` for behavior — only for existence, as
the anchor check above — so it is not a consumer of that protected schema
(surface #3). It never writes `skills-lock.json` (surface #7) and never repairs a
discovery entry (surface #6), because the repair is the thing
`BACKWARD_COMPATIBILITY.md` says a human should do deliberately.

**The discovery check is the core of the design.** For each directory under
`.agents\skills\`, the script asks a single question: **does
`.claude\skills\<name>` resolve to this repository's
`.agents\skills\<name>`?** Existence is not sufficient. Concretely, per entry:

1. Missing from `.claude\skills\` at all → blocker.
2. Present but not a link (a real directory) → blocker. It dispatches, but the
   content is a fork, not this checkout's skill.
3. A link whose target does not exist → blocker.
4. A link whose target resolves anywhere other than this repository's
   `.agents\skills\<name>` → blocker, reported as `foreign:` with the resolved
   target, because the reader needs to know to delete rather than create.
5. Resolves correctly → counted as healthy.

Two Windows details make this correct rather than merely plausible, and both are
verified facts about this checkout rather than assumptions:

- **The entries here are NTFS junctions, not symbolic links.** Every repo
  document (`AGENTS.md`, `README.md`, `BACKWARD_COMPATIBILITY.md` #6) calls them
  symlinks, and the recreation snippet uses `ln -sfn`, but Git Bash on Windows
  without the privilege to create symlinks produces directory junctions —
  `Get-Item` reports `LinkType: Junction` for all 13 entries in this working
  tree. The script must therefore accept **both** `SymbolicLink` and `Junction`
  as valid link types. A check that demands `SymbolicLink` would report a
  perfectly healthy lab as 13 blockers.
- **Targets are absolute and must be compared normalized.** The recreation
  snippet writes absolute targets (`ln -sfn "$PWD/..."`), so a repository that is
  copied or cloned to a second location keeps entries that still resolve — to
  the *old* checkout. Comparison uses `[System.IO.Path]::GetFullPath()` on both
  sides and a case-insensitive match, so drive-letter casing, trailing
  separators, and `.`/`..` segments cannot produce a false `foreign:`.

**Lockfile comparison.** `skills-lock.json` is read with `ConvertFrom-Json`; the
skill names are the property names of its `skills` object. The script compares
that set against the directory names under `.agents\skills\` and reports the
symmetric difference. Any read or parse failure degrades the line to `unreadable`
with a warning — the lockfile is never allowed to abort the report.

**Collection model.** Each check appends to two lists, `$blockers` and
`$warnings`, each entry already formatted as its one- or two-line message. No
check exits early: a repo with three problems reports three problems in one run,
which is the whole point of a status command.

**Blocker vs. warning.** The rule is narrow by decision D9: *would a learning
session started right now fail to dispatch a skill, or dispatch the wrong copy
of one?* Only the discovery failures meet it.

| Condition | Class | Reasoning |
|---|---|---|
| A vendored skill has no `.claude\skills\` entry | blocker | The skill cannot be dispatched; the session hits a dead end. |
| An entry exists but is a real directory, not a link | blocker | Dispatches a forked copy that is not this checkout's source (surface #6). |
| An entry is a link whose target does not exist | blocker | Dispatch fails, and the fix is deletion rather than creation. |
| An entry resolves outside this repository's `.agents\skills\<name>` | blocker | Dispatches another checkout's skill while looking healthy — the failure this script exists to catch. |
| `.claude\skills\` contains an entry with no vendored counterpart | warning | Stale leftover; nothing in this repo dispatches it. |
| A directory under `.agents\skills\` has no `SKILL.md` | warning | Not a dispatchable skill, but nothing else breaks. |
| `skills-lock.json` and `.agents\skills\` disagree on the set | warning | Real drift worth knowing about; nothing breaks until a reinstall. |
| `skills-lock.json` missing or unparseable | warning | Only the lockfile line degrades. |
| Working tree not clean | warning | Legitimate mid-session state, but a PR opened now may carry unintended work. |
| `git` unavailable, or the root is not a git work tree | warning | The Repository section degrades to `unavailable`; skills still dispatch. |
| `EXPERIMENTS.md` / `FINDINGS.md` missing or with no parseable entry | warning | Only the report degrades, printing `none recorded`. |

**Degradation.** Every check is individually optional. A missing file, an absent
`git`, or a command that fails prints `unavailable` (or `none recorded`) for that
line and continues. The script must never abort mid-report; the only fatal
condition is failing the anchor check, which exits `2` before any section prints.

## 📝 Data Model

No persistent state: no cache, no history file, no writes. The script's only data
structures are in-memory variables:

| Name | Shape | Purpose |
|---|---|---|
| `$RepoRoot` | path | Anchor for every relative path, derived from `$PSScriptRoot`. |
| `$Vendored` | string[] | Directory names under `.agents\skills\`. |
| `$Discovery` | hashtable name → status | One of `ok`, `missing`, `not-a-link`, `broken`, `foreign` (with the resolved target), `orphan`. |
| `$LockNames` | string[] or `$null` | Skill names from `skills-lock.json`; `$null` when unreadable. |
| `$blockers`, `$warnings` | string[] | Accumulated findings, each already formatted for display. |

There is no sensitive data in scope. The script prints a branch name, counts,
resolved paths under the repository (and, for a `foreign:` entry, the path it
actually resolves to), and two document headings. It must not print environment
variables, credentials, or the contents of any file other than the three it
parses.

## 📝 API Contracts

The script's contract is its command line, its exit code, and — loosely — its
section headings.

**Invocation.**

```text
.ai\scripts\lab-status.ps1 [-Help]
```

No other parameters in Phase 1. An unsupported parameter such as `-Nope` is
rejected by PowerShell's own parameter binding, which fails **before the script
body runs**, so a future `-Json` or `-Remote` cannot be silently swallowed by an
older copy. What the caller observes depends on *how* the script was invoked, and
the two forms must not be conflated:

- **Direct invocation in the current session** —
  `.\.ai\scripts\lab-status.ps1 -Nope`. Parameter binding fails inside the
  calling session and raises a binding error there; the script body never runs
  and nothing is written to stdout. This is not a process exit, so
  `$LASTEXITCODE` says nothing about it — it keeps whatever value the previous
  native command left behind. A caller detecting this form of failure reads the
  error (`$?`, `$Error[0]`, or a `try`/`catch`), never `$LASTEXITCODE`.
- **Child-process invocation** —
  `powershell -NoProfile -File .\.ai\scripts\lab-status.ps1 -Nope`. Parameter
  binding fails in the child PowerShell process, which exits non-zero, and the
  caller can observe that through `$LASTEXITCODE`. The value is **not** promised
  to be any particular number, and in particular is not `2`: nothing in the
  script has executed by then, so the code comes from the PowerShell host rather
  than from this contract.

`-Help` prints usage to stdout and exits `0` in both forms.

Because the repository ships no execution-policy configuration, a caller on a
restricted machine invokes it as
`powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1`.
This form is what the documentation pointer in Step 5 shows, since a script that
cannot start is indistinguishable from a script that is missing.

**Exit codes.**

| Code | Meaning |
|---|---|
| `0` | Ready — no blockers. Warnings may still have been printed. Also the successful `-Help` exit. |
| `1` | Not ready — at least one blocker was found. |
| `2` | Misuse or wrong context **detected by the script itself** — in Phase 1, the anchored root is not this lab. Reserved for conditions the script body can observe and report. |
| non-zero, unspecified | An unsupported parameter, rejected by PowerShell parameter binding before the script body runs. Observable as an exit code only under child-process invocation; not `2`, and not promised to be any particular value. |

Those three codes are the whole script-controlled contract, and the script sets
each of them with an explicit `exit`, so `$LASTEXITCODE` carries the verdict for
a future wrapper — under direct invocation and under `powershell -File` alike.
Everything outside the table comes from the PowerShell host, not from this
script. A caller that wants to distinguish "not ready" from "could not run" tests
for `1` specifically and treats any other non-zero code as a failure to produce a
report; it must not treat `2` as the only such code, and it must not read
`$LASTEXITCODE` at all when the failure was a binding error raised in its own
session.

**Output shape.** Human-readable ASCII text on stdout, diagnostics on stderr.
Section headings (`Repository`, `Skills`, `Learning log`) and the verdict
prefixes (`READY`, `NOT READY`) are stable enough to grep for, and this spec
declares them an informal contract — changing them is a rename another script
could be resolving, which by `BACKWARD_COMPATIBILITY.md` § "Deciding whether a
change is breaking" means calling it out in the PR body. It is deliberately *not*
promoted to a protected surface: nothing consumes it yet, and adding a ninth
surface for a convenience script would cheapen the list.

**Parsing contract for the learning log.** The script reads each file line by
line, tracking whether it is inside a fenced code block (a line whose trimmed
form starts with three backticks toggles the state), and considers only headings
found **outside** a fence. Outside a fence it matches
`^##\s+(Experiment|Finding)\s+(\d{3})\b` and reports the highest-numbered match,
with the remainder of that heading line as the title.

Fence-awareness is structural, not incidental. `EXPERIMENTS.md` contains an entry
template inside a ```` ```markdown ```` block whose heading is
`## Experiment NNN`; a digit-anchored pattern happens to skip it today, but only
because the placeholder is literally `NNN`. Anyone filling that example in with
digits, or adding a fenced sample of a real entry, would otherwise create a
phantom "latest" entry. Skipping fenced regions removes the coincidence.

`EXPERIMENTS.md` is scanned for `Experiment` headings and `FINDINGS.md` for
`Finding` headings; a heading of the wrong kind in either file is ignored.
Heading suffixes are not uniform — `## Finding 001  (Lesson 1-2)`,
`## Finding 005 — Issue orchestration is explicit and resumable`, and
`## Experiment 001` with no suffix all occur today — so the title is whatever
follows the number, trimmed of leading separators (em dash, hyphen, colon,
whitespace) and truncated for display; an empty remainder prints the number
alone. Highest-numbered rather than last-in-file is deliberate: it is stable
under an out-of-order append, and both files number sequentially by convention.

## 📝 UI/UX

The interface is the terminal output shown under Proposed Solution. Four
constraints govern it:

- **One screen.** The full report is ~14 lines on a healthy repo. If it grows
  past a screen, sections get shorter, not the report longer — the whole value
  is being read at a glance before a session starts.
- **Aligned two-column body.** A fixed label column (18 characters) with values
  left-aligned after it, so the eye scans values vertically. Detail lines (such
  as `missing:  om-fix`) indent into the value column.
- **Findings state the problem, not a script.** Per-finding remediation commands
  are deferred (D9). Each finding names the affected skill and what is wrong with
  it, and the block ends with a single pointer at `README.md` § Start here, which
  already holds the canonical recreation snippet. Reproducing that snippet in the
  script's output would create a fourth copy of it to keep in sync.
- **Plain ASCII only — no color, no Unicode box drawing, no emoji.** The Windows
  console's default code page mangles non-ASCII, and the output ends up in log
  captures and agent transcripts. Severity is carried by the words `[blocker]`
  and `[warning]`, never by color, which also keeps the report correct in a
  screen reader.

No mockups or screenshots accompany this spec: the feature has no graphical
surface and this repository has no application to screenshot. The sample output
blocks above are the visual specification.

## 📝 Edge Cases & Failure Scenarios

| Scenario | Behavior |
|---|---|
| Run from a subdirectory, or with `cwd` inside an unrelated repository | Unaffected: the root comes from `$PSScriptRoot`, never from `cwd`. The report always describes the repository the script lives in. |
| A copy of the script placed outside this lab | The anchor check finds no `.agents\skills\` or no `.ai\agentic.config.json` two levels up, writes a diagnostic to stderr, and exits `2` without printing a report. |
| `.claude\skills\` missing entirely (fresh clone) | Every vendored skill reports `missing`; one blocker per skill, plus the `README.md` pointer — the exact first-run experience `README.md` warns about. |
| A discovery entry is a junction rather than a symbolic link | Healthy. Both link types are accepted; this is the normal state of this checkout. |
| A discovery entry is a real directory | Blocker (`not-a-link`): it dispatches a forked copy rather than this checkout's skill. |
| A discovery entry's target no longer exists | Blocker (`broken`), named separately so the reader knows to delete rather than create. |
| The repository was copied or re-cloned elsewhere, so entries still resolve to the previous checkout | Blocker (`foreign`), printing the resolved target. This is the case that looks healthiest and is the reason existence alone is not the test. |
| Target differs only by drive-letter case, trailing separator, or `..` segments | Healthy: both sides are normalized with `GetFullPath()` and compared case-insensitively before any `foreign` verdict. |
| `.claude\skills\` holds an entry with no vendored counterpart | Warning (`orphan`), named in the Skills section; nothing in this repo dispatches it. |
| A directory under `.agents\skills\` has no `SKILL.md` | Counted as vendored, plus one warning — a directory with no `SKILL.md` is not a dispatchable skill. |
| `skills-lock.json` absent, unreadable, or malformed | Lockfile line prints `unreadable`; one warning. `ConvertFrom-Json` failure is caught, never fatal. |
| `git` absent, or the anchored root is not a git work tree | Repository section prints `unavailable` for both lines; one warning. Discovery and learning-log sections still run. |
| An automation worktree exists under `.ai\tmp\` | `.ai/tmp/` is not gitignored, so `git status --porcelain` counts it and the working tree reports dirty. Accepted for Phase 1 and documented here: the tree-dirty finding is a warning, never a blocker, so it cannot flip the verdict. Distinguishing automation worktrees is deferred (D9). |
| `EXPERIMENTS.md` or `FINDINGS.md` missing, empty, or containing only the template | Prints `none recorded`; one warning, since a lab with no log is unusual but not broken. |
| A fenced code block contains a heading such as `## Experiment 003` | Ignored. Fence tracking excludes it, so a documentation example cannot become the reported latest entry. |
| Terminal narrower than the label column | Lines wrap; nothing is truncated to fit. Legibility loses to completeness. |
| Script run twice concurrently | Safe by construction — read-only, no temp files, no locks. |

## 📝 Risks & Impact Review

**Blast radius: near zero.** The change adds one new file under `.ai/scripts/`
and a short pointer in two documents. It touches no skill, no descriptor, and no
configuration. Nothing in the pipeline dispatches to it, so a bug in it cannot
fail a PR, a review, or a merge — the worst outcome is a wrong report on a
terminal.

**Protected surfaces** (`BACKWARD_COMPATIBILITY.md`):

- **#5, directory contract under `.ai/`** — respected: the script lands in
  `paths.scripts`, which the repo already commits. No path moves. Note for the
  Step 5 documentation edit: `README.md` currently describes `.ai/scripts/` as
  holding *generated* launchers, so the row should acknowledge that this one is
  hand-maintained and is not regenerated by `om-setup-agent-pipeline`.
- **#3, `.ai/agentic.config.json` schema** — untouched. The reduced scope drops
  the validation-gate check entirely, so the script neither reads
  `validation.commands` nor duplicates its value; it only tests the file's
  existence as part of the anchor check. The first draft's risk of a third,
  drifting copy of the gate command no longer exists.
- **#1 skill names, #2 reference paths, #7 `skills-lock.json`** — untouched. The
  script *reads* the lockfile and must never write it.
- **#6 discovery entries** — the script reports on them and must never repair
  them, precisely because the repair is the thing the doc says a human should do
  deliberately.
- No new protected surface is created. The section headings and exit codes are
  documented as an informal contract in API Contracts, not promoted to the list.

**Risks:**

1. *The repository's documentation and its reality disagree about link type.*
   Every doc says "symlink"; the actual entries are junctions. The script accepts
   both, so it is correct either way, but a future reader may find the mismatch
   confusing. Fixing the documentation is out of scope here — the script must not
   depend on the docs being corrected, which is why the accepted link types are
   stated in Architecture rather than inferred from `BACKWARD_COMPATIBILITY.md`.
2. *False confidence.* `READY` means "the checks this script knows about passed",
   not "nothing is wrong" — and Phase 1 knows about fewer checks than the first
   draft proposed. Mitigated by the verdict line naming counts rather than making
   an absolute claim, and by keeping the check list short enough that a reader
   knows what it covers.
3. *No linting for PowerShell in this repo.* The validation gate is
   `git diff --check`; a syntax error would ship unnoticed until someone ran the
   script. Mitigated by the verification fixture in the implementation plan,
   which runs the script in healthy and broken states before the PR opens, and by
   parsing the script with
   `[System.Management.Automation.PSParser]::Tokenize()` as an explicit check in
   Step 1.
4. *PowerShell 5.1 only.* `pwsh` is not installed on the development machine, so
   the script targets Windows PowerShell 5.1 and must avoid PowerShell 7 syntax
   (`??`, ternaries, `ConvertFrom-Json -AsHashtable`). `#Requires -Version 5.1`
   states the floor; a 7.x host runs it unchanged.

**Rollback:** delete `.ai/scripts/lab-status.ps1` and revert the two
documentation pointers added in Step 5. There is no migration, no state, and no
programmatic consumer, so a revert is complete by construction.

## 📋 Phasing

**Phase 1 — the minimal status report.** Everything in this spec: the three
sections, the verdict, the exit codes, and the doc pointers that make it
discoverable. Independently shippable and complete on its own.

**Phase 2 (deferred, not part of this spec) — the deliberately excluded checks**,
listed so a later reader knows they were considered and why they are absent:
`gh` and `jq` presence and version checks, upstream ahead/behind reporting, a
validation-gate (`git diff --check`) check, active-worktree diagnostics, remote
and tracker state, per-finding remediation commands, `-Json`, `-Remote`, and
lockfile hash verification. None is started until something concretely needs it.
Two carry design notes worth keeping: a validation-gate check must not duplicate
`validation.commands` from `.ai/agentic.config.json` without registering the new
copy in the "change these together" instructions in `AGENTS.md` § Validation and
`SDLC.md` § Validation gate; and `git diff --check` compares the working tree to
the index, so on the clean checkout a session starts from it always passes and
certifies nothing.

## 📋 Implementation Plan

Each step leaves the repository in a working state — trivially true here, since
until Step 5 the script is a new file nothing references.

### Verification fixture

Steps 2–4 need broken repositories to test against, and no step may touch the
developer's real `.claude\skills\` entries: on a machine without the privilege to
create links, a mis-restored entry cannot simply be recreated. Every negative
test therefore runs against a **scratch clone** outside the repository, built
once and reused:

```powershell
$fixture = Join-Path $env:TEMP "lab-status-fixture"
git clone --no-hardlinks . $fixture
New-Item -ItemType Directory -Path "$fixture\.claude\skills" | Out-Null
Get-ChildItem "$fixture\.agents\skills" -Directory | ForEach-Object {
  New-Item -ItemType Junction -Path "$fixture\.claude\skills\$($_.Name)" -Target $_.FullName | Out-Null
}
Copy-Item .\.ai\scripts\lab-status.ps1 "$fixture\.ai\scripts\lab-status.ps1"
```

Junctions need no elevation or Developer Mode, so the fixture reproduces this
checkout's real discovery shape. Because the script anchors on `$PSScriptRoot`,
the copy inside the fixture reports on the fixture. Delete the fixture when the
step is done; it lives under `$env:TEMP`, never inside the repository.

### Phase 1

1. **Create the script skeleton.** Add `.ai/scripts/lab-status.ps1` with
   `#Requires -Version 5.1`, `Set-StrictMode -Version Latest`, a `[switch]$Help`
   parameter with usage text, `$ErrorActionPreference` handling that keeps the
   report going, root resolution from `$PSScriptRoot` with the
   `.agents\skills\` + `.ai\agentic.config.json` anchor check and exit `2`, the
   two finding lists, and a `main` that prints the three (still empty) section
   headings and the verdict.
   *Verify:* the script prints three headings and `READY` and exits `0`;
   `-Help` prints usage and exits `0`. The unsupported-parameter case is checked
   in both invocation forms, and each asserts only what that form guarantees:
   `.\.ai\scripts\lab-status.ps1 -Nope` raises a binding error in the current
   session and prints no report — assert the error (`$?` false, or a
   `try`/`catch`), and do **not** assert `$LASTEXITCODE`, which the binding
   failure never sets; `powershell -NoProfile -File .\.ai\scripts\lab-status.ps1
   -Nope` leaves a **non-zero** `$LASTEXITCODE` — assert non-zero only, not a
   specific value. A copy placed in a directory outside the lab exits exactly `2`
   with a stderr diagnostic and no report;
   `[System.Management.Automation.PSParser]::Tokenize()` over the file returns no
   parse errors.
2. **Implement the Repository section.** Current branch and working-tree
   cleanliness from `git status --porcelain`, run with `-C $RepoRoot` so the
   caller's directory is irrelevant. Wire the dirty-tree warning. Degrade both
   lines to `unavailable` with one warning when `git` is missing or the root is
   not a work tree.
   *Verify:* a clean checkout reports the branch and `clean` and exits `0`; after
   creating a scratch file in the fixture, the warning appears and the exit code
   stays `0`; with `git` removed from `PATH` for one invocation, both lines print
   `unavailable`, the section does not abort, and the exit code stays `0`.
3. **Implement the Skills section.** Enumerate directories under
   `.agents\skills\`, then classify each against `.claude\skills\` per the five
   cases in Architecture: `ok`, `missing`, `not-a-link`, `broken`, `foreign`.
   Accept `LinkType` of both `SymbolicLink` and `Junction`. Compare targets with
   `[System.IO.Path]::GetFullPath()` on both sides, case-insensitively. Add the
   `orphan` warning for unmatched `.claude\skills\` entries and the warning for
   vendored directories lacking a `SKILL.md`. Read `skills-lock.json` with
   `ConvertFrom-Json` inside a `try`, take the property names of its `skills`
   object, report the set difference, and degrade to `unreadable` on any failure.
   *Verify (all in the fixture, never in the real checkout):* the untouched
   fixture reports `13 of 13`; deleting one junction produces the `missing`
   blocker and exit `1`; replacing one with a real directory produces the
   `not-a-link` blocker; repointing one at a junction into a second copy of the
   repository produces the `foreign` blocker with the resolved target printed;
   deleting a junction's target produces `broken`; adding
   `.claude\skills\om-ghost` produces the `orphan` warning with exit `0`;
   truncating `skills-lock.json` to invalid JSON produces `unreadable` with a
   warning and no crash.
4. **Implement the Learning log section.** Read `EXPERIMENTS.md` and
   `FINDINGS.md` line by line with fence tracking, match
   `^##\s+(Experiment|Finding)\s+(\d{3})\b` outside fences only, take the highest
   number per file, trim the title separators, truncate for display, and print
   `none recorded` with a warning when nothing matches or the file is absent.
   *Verify:* the section reports experiment `002` and finding `005` with their
   titles; the `## Experiment NNN` template inside the fenced block is not
   reported; adding `## Experiment 999` **inside** a fenced block in the fixture
   does not change the reported latest, while adding the same heading outside a
   fence does; deleting `FINDINGS.md` in the fixture prints `none recorded` with
   a warning and exit `0`.
5. **Finalize the verdict, then make it discoverable.** Render the accumulated
   findings under the verdict with `[blocker]` / `[warning]` prefixes and the
   single `README.md` pointer line; set the exit code from the blocker count;
   confirm the report matches the alignment rules in UI/UX. Then add the script
   to the repository map in `README.md` (noting it is hand-maintained, not a
   generated launcher) and to the routing table in `AGENTS.md` as a "checking
   whether the repo is session-ready" row, and mention in `README.md` § Start
   here that running it is the fastest way to confirm the discovery step worked.
   Keep both edits to a few lines — the script's `-Help` is the reference, the
   docs are the pointer.
   *Verify:* a fixture broken in two ways (one deleted junction plus a dirty
   tree) produces exactly the two-finding shape shown in Proposed Solution and
   exits `1`; the real checkout exits `0`; `git diff --check` passes; the command
   shown in `README.md` runs as written, including on a restricted execution
   policy; the fixture is deleted.

### Out of scope for this plan

No changes to any file under `.agents/skills/`, `.ai/trackers/`, `.ai/browsers/`,
or `.ai/agentic.config.json`, and no changes to the `.claude/skills/` entries of
the working checkout. If implementing this appears to require one, that is a
signal the design drifted and the spec should be amended first.
