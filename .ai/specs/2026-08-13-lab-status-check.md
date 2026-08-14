# Lab status check

## 📝 TLDR

`om-skills-learning-lab` has no build system, so there is no `npm start` that
fails loudly when the repository is not usable. The things that actually break a
learning session — missing skill-discovery symlinks, an unclean or diverged
working tree, a `gh` client too old for the tracker descriptor — all fail
quietly, at the moment a skill is dispatched rather than at the moment the
repository is opened. This spec proposes `.ai/scripts/lab-status.sh`: one
read-only POSIX shell script that answers "is this repo ready for the next
learning session?" in a few seconds, printing repository state, installed-skill
discovery health, toolchain versions, and the latest recorded experiment and
finding, then a `READY` / `NOT READY` verdict backed by its exit code.

## 📝 Resolved assumptions (autonomous defaults)

This spec was written by `om-auto-write-spec` in autonomous mode. The Open
Questions raised by the skeleton were resolved with the most reversible,
smallest-scope answer available, and every one of them is listed here so a human
can override it before the spec is implemented.

| # | Question | Applied default | Why | Confirm? |
|---|----------|-----------------|-----|----------|
| Q1 | Should this ship as a shell script under `.ai/scripts/`, as a new `om-*` skill under `.agents/skills/`, or both? | A single POSIX shell script, `.ai/scripts/lab-status.sh`. | Smallest new surface and the only option that adds no name to a protected surface: `.ai/scripts/` is already the committed home for reproducible launchers (protected surface #5), while a new skill would add a skill name (#1), reference paths (#2), and a `skills-lock.json` question (#7) for a report a script already produces. A skill can wrap the script later without changing it. | ok |
| Q2 | Does "ready" include remote/tracker state — open PRs, issue claims, `gh auth status` — or only local state? | Local state only; no network call in the whole script. | Keeps the script fast, offline-capable, and free of authentication failure modes, and the brief names only repository state, installed skills, and the learning log. Tracker readiness is already visible through the skills that own it. Adding a `--remote` section later is purely additive. | ok |
| Q3 | Should the output be human-readable text only, or also a machine-readable `--json` mode? | Human-readable text only. | The consumer named in the brief is a human about to start a session. A JSON mode is a data contract that other tooling would then depend on; deferring it costs nothing and avoids freezing a schema before anything consumes it. | ok |
| Q4 | Should the exit code carry the verdict, or should the script always exit 0? | `0` when ready, `1` when at least one blocker was found, `2` on script misuse. | A verdict a human reads is strictly less useful than one a future wrapper can branch on, and the exit code is the cheapest possible machine surface — no format, no parsing. Reversible: widening the meaning of a non-zero exit later breaks nothing that treats `0` as ready. | ok |
| Q5 | Should the script verify vendored-skill integrity by recomputing the `computedHash` values in `skills-lock.json`? | No — compare only the *set* of skill names in the lockfile against the directories under `.agents/skills/`. | Recomputing the hash means reimplementing the `skills` CLI's algorithm in shell and keeping it in sync forever; getting it subtly wrong produces false drift warnings on every run, which is worse than not checking. Local edits to vendored skills are expected in a learning lab anyway, so hash drift is weak evidence. Presence mismatch, by contrast, is unambiguous and trivial to check. | ok |
| Q6 | Should the script fix what it finds — recreate missing symlinks, stash changes? | No. It is strictly read-only and prints the exact command that fixes each problem. | A status check that mutates the repository cannot be run casually, which defeats its purpose; and the one repair it would plausibly perform (recreating `.claude/skills/` symlinks) already exists as a documented snippet in `README.md` and `AGENTS.md`. | ok |
| Q7 | Does the brief bundle more than one independently deployable capability? | No — it is one report, shipped as one script, in one phase. | Repository state, skill discovery, and the learning log are three sections of a single output; none of them ships or is useful without the surrounding report. | ok |

## 📝 Problem Statement

This repository is Markdown that an agent executes, with no compiler, linter, or
test runner (`AGENTS.md` § Validation). That has a specific consequence: **every
readiness problem here fails silently and late.** The failure surfaces as a skill
that does not dispatch, or an agent that reads a stale file, rather than as a
build error.

The concrete failure modes, all already documented in this repo as things that
have bitten someone:

- **Skill discovery is missing after a clone.** `.claude/` is gitignored, so a
  fresh clone contains `.agents/skills/` but nothing that dispatches to it
  (`README.md` § Start here). The symptom is "the skill doesn't exist", with no
  error pointing at the symlinks.
- **A discovery entry has become a real directory instead of a symlink.** On
  Windows without Developer Mode this happens by accident, and it forks a skill
  into two copies that drift apart — protected surface #6 in
  `BACKWARD_COMPATIBILITY.md`. Nothing reports it; the two copies simply stop
  agreeing.
- **The `gh` client is too old.** Below 2.82.1 every label and assignee edit
  aborts on the retired Projects (classic) API, printing what looks like a
  deprecation warning while leaving the PR unlabeled
  (`.ai/trackers/github.md` § Prerequisites). This is the single most confusing
  failure in the whole pipeline because it looks like it worked.
- **The working tree is dirty or diverged from `origin/main`.** A session that
  starts on someone else's half-finished branch, or on top of uncommitted skill
  edits, produces a PR that contains work nobody meant to ship.
- **Nobody remembers where the learning log left off.** `EXPERIMENTS.md` and
  `FINDINGS.md` are the record of what this lab has established, and the next
  session normally continues from the last entry — which currently means opening
  two files and scrolling to the bottom of each.

Every one of these is answerable from the local filesystem in well under a
second. What is missing is a single place that asks all of them at once.

## 📝 Proposed Solution

Add one executable POSIX shell script, `.ai/scripts/lab-status.sh`, run from the
repository root:

```console
$ .ai/scripts/lab-status.sh
```

It performs four groups of read-only checks, prints one section per group, and
ends with a verdict. It never writes to the repository, never makes a network
call, and depends on nothing beyond `git`, `sh`, and the standard text utilities
already required to use this repo.

### Sample output

```text
om-skills-learning-lab — status

Repository
  Branch            main (up to date with origin/main)
  Working tree      clean
  Validation gate   git diff --check ... ok
  Last commit       448960b docs(readme): explain the lab's purpose ...

Skills
  Vendored          13 under .agents/skills/
  Discoverable      13 of 13 linked into .claude/skills/
  Lockfile          13 entries in skills-lock.json, matching

Learning log
  Latest experiment 002 — Autonomous issue orchestration from a plain brief
  Latest finding    005 — Issue orchestration is explicit and resumable

Toolchain
  git               2.51.0
  gh                2.92.0 (>= 2.82.1 required)
  jq                1.8.1

READY — no blockers found.
```

And a failing run, which is the case the script exists for:

```text
Skills
  Vendored          13 under .agents/skills/
  Discoverable      11 of 13 linked into .claude/skills/
                    missing: om-fix, om-root-cause
  Lockfile          13 entries in skills-lock.json, matching

...

NOT READY — 1 blocker, 1 warning.

  [blocker] 2 skills have no .claude/skills/ entry and cannot be dispatched.
            Recreate the discovery symlinks:
              mkdir -p .claude/skills
              for s in .agents/skills/*/; do
                ln -sfn "$PWD/${s%/}" ".claude/skills/$(basename "$s")"
              done
  [warning] Working tree has 3 uncommitted changes; a PR opened now may
            include work you did not intend to ship. Review: git status --short
```

### Alternatives considered

- **A new `om-lab-status` skill.** Rejected as the primary form: it adds a skill
  name, a reference-path tree, and a `skills-lock.json` question (protected
  surfaces #1, #2, #7) to deliver a report that is deterministic and needs no
  model reasoning. A skill that shells out to this script remains available
  later, and is strictly easier to add once the script exists.
- **Extending `om-setup-agent-pipeline` with a `--check` mode.** Rejected: that
  skill is the setup *authority* and is expected to write files; folding a
  read-only check into it blurs a boundary this repo deliberately keeps sharp,
  and it is a vendored skill, so editing it in place drifts its lockfile hash.
- **A `Makefile` / `npm` script.** Rejected: this repo has no toolchain, and
  adding one to host a five-second check inverts the cost.

## 📝 Architecture

One file. `.ai/scripts/lab-status.sh`, executable, `#!/bin/sh`, no sourcing of
anything else in the repo.

```text
lab-status.sh
├── resolve repo root ......... git rev-parse --show-toplevel; abort if not a repo
├── section: Repository ....... git-only checks
├── section: Skills ........... filesystem + skills-lock.json checks
├── section: Learning log ..... EXPERIMENTS.md / FINDINGS.md heading scan
├── section: Toolchain ........ version probes for git, gh, jq
└── verdict ................... collected blockers/warnings → text + exit code
```

**Boundaries.** The script reads the repository and the `PATH`; it writes only to
stdout and stderr. It does not read `.ai/agentic.config.json` for behavior — the
config drives *skills*, and a status script that also parsed it would be a second
consumer of a protected schema (surface #3) for no benefit. The one exception is
the validation gate: the command the script runs (`git diff --check`) is the same
command `.ai/agentic.config.json` names in `validation.commands`, and the spec
records that as a deliberate duplication of a one-line constant rather than a
config dependency. If this repo ever grows a real validation command list, the
script's gate check should be revisited — noted in Risks.

**Collection model.** Each check appends to two accumulators, `BLOCKERS` and
`WARNINGS` (newline-separated strings; no arrays, to stay POSIX). A check never
exits early — a repo with three problems reports three problems in one run, which
is the whole point of a status command.

**Blocker vs. warning.** The distinction is: *would a learning session started
right now silently produce wrong results?*

| Condition | Class | Reasoning |
|---|---|---|
| A vendored skill has no `.claude/skills/` entry | blocker | The skill cannot be dispatched at all; the session hits a dead end. |
| A `.claude/skills/` entry exists but is not a symlink | warning | Dispatch still works, so the session runs — but the copy has forked from `.agents/` and will drift (protected surface #6). |
| `gh` missing, or older than 2.82.1 | blocker | Every tracker label and assignee edit fails while appearing to succeed. |
| `jq` missing | blocker | The tracker descriptor's label guards parse JSON with it. |
| `git diff --check` fails | blocker | The repo's entire validation gate is red; nothing should be committed. |
| Working tree not clean | warning | Legitimate mid-session state, but a PR opened now may carry unintended work. |
| Branch diverged from its upstream | warning | Same: normal during work, dangerous at the start of a session. |
| `skills-lock.json` and `.agents/skills/` disagree on the skill set | warning | Real drift worth knowing about, but nothing breaks until that skill is invoked. |
| `EXPERIMENTS.md` / `FINDINGS.md` has no parseable entry | warning | Only the report degrades, printing `none recorded`. |

**Degradation.** Every check is individually optional. A missing file, an absent
binary, or a `git` command that fails prints `unavailable` (or `none recorded`)
for that line and continues. The script must never abort mid-report; the only
fatal condition is not being inside a git repository, which exits `2`.

## 📝 Data Model

No persistent state: no cache, no history file, no writes. The script's only data
structures are shell variables:

| Name | Shape | Purpose |
|---|---|---|
| `REPO_ROOT` | path | Anchor for every relative path; the script `cd`s here first so it can be run from anywhere. |
| `BLOCKERS`, `WARNINGS` | newline-separated text | Accumulated findings, each already formatted with its remediation line. |
| `BLOCKER_COUNT`, `WARNING_COUNT` | integer | Verdict line arithmetic. |

There is no sensitive data in scope. The script prints branch names, commit
subjects, tool versions, and document headings — nothing that could carry a
credential. It must not print environment variables, `gh auth token` output, or
the contents of any file outside the three it parses.

## 📝 API Contracts

The script's contract is its command line, its exit code, and — loosely — its
section headings.

**Invocation.**

```text
.ai/scripts/lab-status.sh [--help]
```

No other flags in Phase 1. An unrecognized argument prints usage to stderr and
exits `2` rather than being ignored, so a future `--json` or `--remote` cannot be
silently swallowed by an older copy of the script.

**Exit codes.**

| Code | Meaning |
|---|---|
| `0` | Ready — no blockers. Warnings may still have been printed. |
| `1` | Not ready — at least one blocker. |
| `2` | Misuse or wrong context: unknown flag, or not run inside a git repository. |

**Output shape.** Human-readable text on stdout, diagnostics on stderr. Section
headings (`Repository`, `Skills`, `Learning log`, `Toolchain`) and the verdict
prefixes (`READY`, `NOT READY`) are stable enough to grep for, and this spec
declares them the informal contract — changing them is a rename another script
could be resolving, which by `BACKWARD_COMPATIBILITY.md` § "Deciding whether a
change is breaking" means calling it out in the PR body. It is deliberately *not*
promoted to a protected surface: nothing consumes it yet, and adding a ninth
surface for a convenience script would cheapen the list.

**Parsing contract for the learning log.** The script scans for headings matching
`^## (Experiment|Finding) ([0-9]{3})` and reports the highest-numbered match,
along with the remainder of that heading line as its title. Two details make this
correct rather than merely plausible, and both must be covered by tests:

- `EXPERIMENTS.md` contains an **entry template inside a fenced code block**
  whose heading is `## Experiment NNN`. The `[0-9]{3}` anchor excludes it, which
  is why the pattern requires digits rather than accepting any suffix.
- Heading suffixes are **not uniform**: `## Finding 001  (Lesson 1-2)`,
  `## Finding 005 — Issue orchestration is explicit and resumable`, and
  `## Experiment 001` with no suffix at all all occur today. The title is
  whatever follows the number, trimmed of leading separators (`—`, `-`, `:`,
  whitespace) and truncated for display; an empty remainder is fine and prints
  the number alone.

Highest-numbered, not last-in-file, is the deliberate choice: it is stable under
an out-of-order append, and both files number sequentially by convention.

## 📝 UI/UX

The interface is the terminal output shown under Proposed Solution. Four
constraints govern it:

- **One screen.** The full report is ~16 lines on a healthy repo. If it grows
  past a screen, sections get shorter, not the report longer — the whole value
  is being read at a glance before a session starts.
- **Aligned two-column body.** A fixed label column (18 characters) with values
  left-aligned after it, so the eye scans values vertically. Detail lines (such
  as `missing: om-fix, om-root-cause`) indent into the value column.
- **Every blocker carries its fix.** No finding is printed without the exact
  command that resolves it, copy-pasteable. A status check that reports a problem
  and leaves the reader to search the docs has done half a job.
- **No color, no Unicode box-drawing, no spinner.** Plain ASCII survives every
  terminal, log capture, CI pane, and agent transcript this repo's output ends up
  in. Emoji and color are what the *skills* use in their reports; a script that
  might be piped should not.

Accessibility: because the output is plain text with a stable label column, it
reads correctly in a screen reader and never encodes meaning in color alone —
severity is carried by the words `[blocker]` and `[warning]`.

No mockups or screenshots accompany this spec: the feature has no graphical
surface, `om-prepare-test-env` is not installed in this repository, and this
repository has no application to screenshot. The sample output blocks above are
the visual specification.

## 📝 Edge Cases & Failure Scenarios

| Scenario | Behavior |
|---|---|
| Run from a subdirectory, or from another repo's checkout | `git rev-parse --show-toplevel` anchors it; run outside any repository, it prints a usage error to stderr and exits `2`. |
| Run inside one of this repo's temporary worktrees under `.ai/tmp/` | Reports honestly on *that* worktree — its branch, its tree, its `.claude/` absence. The `.claude/` symlinks live only in the primary checkout, so the Skills section will report every skill as undiscoverable. The script detects a linked worktree (`git rev-parse --git-dir` differs from `--git-common-dir`) and downgrades the discovery blocker to a warning that names the cause, rather than reporting a broken repo. |
| No upstream configured for the current branch | Prints `no upstream` and raises no finding — a local-only branch is normal. |
| Ahead/behind counts computed without a fetch | Deliberate: no network. The line says `vs origin/main (as of last fetch)` so a stale comparison cannot be mistaken for a fresh one. |
| `.claude/skills/` missing entirely (fresh clone) | Single blocker naming all skills as undiscoverable, with the symlink-recreation snippet — the exact first-run experience `README.md` warns about. |
| A `.claude/skills/` entry pointing at a path that no longer exists (broken symlink) | Counted as missing (blocker), and named separately as `broken: <name>` so the reader knows to delete rather than create. |
| `skills-lock.json` absent or malformed | Lockfile line prints `unreadable`, one warning. The script must not `jq`-parse it fatally; skill names are extracted defensively and a parse failure degrades to `unreadable`. |
| `jq` absent while `skills-lock.json` is present | Blocker for `jq` itself (the tracker guards need it); the lockfile line degrades to `unreadable — jq not installed`, not a second finding. |
| `EXPERIMENTS.md` or `FINDINGS.md` missing, empty, or containing only the template | Prints `none recorded`; one warning, since a lab with no log is unusual but not broken. |
| A skill directory exists under `.agents/skills/` without a `SKILL.md` | Counted as vendored but flagged in a warning — a directory with no `SKILL.md` is not a dispatchable skill. |
| Terminal narrower than the label column | Lines wrap; nothing is truncated to fit. Legibility loses to completeness. |
| Script run twice concurrently | Safe by construction — read-only, no temp files, no locks. |

## 📝 Risks & Impact Review

**Blast radius: near zero.** The change adds one new file under `.ai/scripts/`,
touches no skill, no descriptor, and no configuration. Nothing in the pipeline
dispatches to it, so a bug in it cannot fail a PR, a review, or a merge — the
worst outcome is a wrong report on a terminal.

**Protected surfaces** (`BACKWARD_COMPATIBILITY.md`):

- **#5, directory contract under `.ai/`** — respected: the script lands in
  `paths.scripts`, which the repo already commits and describes as the home for
  launchers kept "so the environment stays reproducible". No path moves.
- **#1 skill names, #2 reference paths, #7 `skills-lock.json`** — untouched. The
  script *reads* the lockfile and must never write it.
- **#6 discovery symlinks** — the script reports on them and must never repair
  them, precisely because the repair is the thing the doc says a human should do
  deliberately.
- No new protected surface is created. The section headings and exit codes are
  documented as an informal contract in API Contracts, not promoted to the list.

**Risks:**

1. *The validation-gate check duplicates a config value.* The script hardcodes
   `git diff --check` while `.ai/agentic.config.json` names it in
   `validation.commands`. If the repo grows a real toolchain, the two drift and
   the script under-reports. Mitigated by a comment at that line pointing at the
   config, and by the fact that adding a validation command is already a change
   that `SDLC.md` § Validation gate requires touching multiple files for.
2. *False confidence.* `READY` means "the checks this script knows about passed",
   not "nothing is wrong". Mitigated by the verdict line naming the counts rather
   than making an absolute claim, and by keeping the check list short enough that
   a reader knows what it covers.
3. *Windows shell portability.* The script is POSIX `sh` run under Git Bash on
   the primary development machine. `sh -n` linting is not part of any gate here,
   so a syntax error ships unnoticed until someone runs it. Mitigated by the
   manual verification steps in the implementation plan, which run the script in
   both healthy and broken states before the PR opens.

**Rollback:** delete the file. There is no migration, no state, and no consumer —
a revert is complete by construction.

## 📋 Phasing

**Phase 1 — the script and its documentation.** Everything in this spec: the
four sections, the verdict, the exit codes, and the doc pointers that make it
discoverable. Independently shippable and complete on its own; this is the only
phase required to satisfy the brief.

**Phase 2 (deferred, not part of this spec) — the deliberately excluded
extensions**, listed so a later reader knows they were considered and why they
are absent: a `--json` mode (Q3), a `--remote` section covering open PRs and
issue claims (Q2), lockfile hash verification (Q5), and an `om-lab-status` skill
wrapping the script (Q1). None is started until something concretely needs it.

## 📋 Implementation Plan

Each step leaves the repository in a working state — trivially true here, since
until Step 6 the script is a new file nothing references.

### Phase 1

1. **Create the script skeleton.** Add `.ai/scripts/lab-status.sh` with the
   shebang, `set -u`, `--help`/usage handling with exit `2` on an unknown flag,
   repo-root resolution with exit `2` outside a repository, the two finding
   accumulators, and a `main` that prints the four (still empty) section headings
   and the verdict. Mark it executable (`git update-index --chmod=+x`).
   *Verify:* `.ai/scripts/lab-status.sh` prints four headings and `READY`, exits
   `0`; `.ai/scripts/lab-status.sh --nope` prints usage to stderr and exits `2`;
   running it from `/tmp` exits `2`.
2. **Implement the Repository section.** Branch name, upstream comparison
   (ahead/behind from existing refs, no fetch, `no upstream` when unset),
   working-tree cleanliness from `git status --porcelain`, the `git diff --check`
   gate, and the last commit's short SHA and subject. Wire the clean-tree,
   divergence, and gate findings into the accumulators at the classes named in
   Architecture.
   *Verify:* clean checkout reports `clean` and exits `0`; after touching a file,
   the warning appears and the exit code stays `0`; a file with trailing
   whitespace makes the gate fail and the exit code becomes `1`.
3. **Implement the Skills section.** Count directories under `.agents/skills/`,
   resolve each against `.claude/skills/`, and classify per the blocker/warning
   table: missing, broken symlink, present-but-not-a-symlink, and vendored
   directories lacking a `SKILL.md`. Add the linked-worktree detection that
   downgrades the discovery blocker. Extract the lockfile's skill set defensively
   and compare, degrading to `unreadable` on any parse failure or missing `jq`.
   *Verify:* healthy checkout reports `13 of 13`; after `mv .claude/skills/om-fix
   /tmp/`, the blocker names `om-fix` and prints the recreation snippet, exit `1`;
   restoring it returns to `READY`; running the script inside a `.ai/tmp/`
   worktree yields the downgraded warning, not a blocker.
4. **Implement the Learning log and Toolchain sections.** Scan `EXPERIMENTS.md`
   and `FINDINGS.md` for `^## (Experiment|Finding) ([0-9]{3})`, take the
   highest number, trim the title separators, and print `none recorded` when
   nothing matches. Probe `git`, `gh`, and `jq` versions; apply the 2.82.1
   comparison for `gh` (sorted-version comparison, with an inspection fallback
   where `sort -V` is unavailable, mirroring `.ai/trackers/github.md`
   § auth-check).
   *Verify:* the log section reports experiment `002` and finding `005` with
   their titles, and does **not** report the `## Experiment NNN` template inside
   the fenced block; `PATH` without `jq` produces the `jq` blocker and the
   `unreadable — jq not installed` lockfile line; a stubbed `gh` reporting 2.72.0
   produces the version blocker.
5. **Finalize the verdict and remediation text.** Render the accumulated findings
   under the verdict with `[blocker]` / `[warning]` prefixes, each followed by its
   indented fix command; set the exit code from the blocker count; confirm the
   whole report fits the alignment rules from UI/UX.
   *Verify:* a deliberately broken checkout (missing symlink + dirty tree)
   produces exactly the two-finding output shown in Proposed Solution and exits
   `1`; a healthy one exits `0`.
6. **Make it discoverable in the docs.** Add the script to the repository map in
   `README.md` and to the routing table in `AGENTS.md` (a "checking whether the
   repo is session-ready" row), and mention in `README.md` § Start here that
   running it is the fastest way to confirm the symlink step worked. Keep both
   edits to a few lines — the script's `--help` is the reference, the docs are
   the pointer.
   *Verify:* `git diff --check` passes; the README snippet and the script's
   actual behavior agree.

### Out of scope for this plan

No changes to any file under `.agents/skills/`, `.ai/trackers/`,
`.ai/browsers/`, or `.ai/agentic.config.json`. If implementing this appears to
require one, that is a signal the design drifted and the spec should be amended
first.
