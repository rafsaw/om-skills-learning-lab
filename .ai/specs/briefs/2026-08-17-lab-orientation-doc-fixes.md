# Fix stale skill-coverage facts in AGENTS.md and README and make the v16 learning map the lab's orientation surface

- Date: 2026-08-17
- Category: documentation
- Priority signal: medium — nothing is blocked, but `AGENTS.md` actively misinforms any agent that reads it before starting work, and a wrong coverage table is worse than a missing one.
- Risk signal: low — two prose files, no code, no format contract; the only real hazard is deleting the still-true half of the coverage-gap table, which this brief explicitly forbids.
- Routing: Next: om-auto-create-pr "Fix stale skill-coverage facts in AGENTS.md and README and make the v16 learning map the lab's orientation surface — brief: .ai/specs/briefs/2026-08-17-lab-orientation-doc-fixes.md"

## Problem

Returning to the lab after a break, the operator cannot quickly tell which skills have actually been exercised, which were only read about, and what the current learning direction is. That record does exist — `learning-map/om-skills-learning-map-v16.html` carries a per-skill coverage table in an `observed` / `documented` / `not tested` vocabulary, an explicit "Evidence rule" keeping `documented` from silently becoming `observed`, and a numbered knowledge-gap list that is the learning direction written down — but nothing in the repository points at it, so it is not found on return.

Meanwhile the two documents that *are* found on return state things that are false. `AGENTS.md`, section "Installed skills and known coverage gaps", declares six skills installed (`om-setup-agent-pipeline`, `om-code-review`, `om-auto-review-pr`, `om-open-pr`, `om-approve-merge-pr`, `om-check-and-commit`) while 23 are installed under `.agents/skills/` and pinned in `skills-lock.json`. Its "Not installed, but referenced" table lists `om-auto-create-pr`, `om-auto-continue-pr`, `om-auto-qa-pr`, `om-auto-write-spec`, `om-auto-implement-spec`, `om-spec-writing`, and `om-brainstorm` as absent — all seven are installed, and Experiments 003–006 document them running. `README.md` names `om-skills-learning-map-v5.html` the "current revision" although v16 exists, and its `.ai/browsers/agent-browser.md` row says the UI-verification skill is "not installed here" although `om-auto-qa-pr` is installed.

This is a discoverability and truthfulness defect, not a missing-record defect. That distinction is the whole point of the change.

## Agreed direction

Correct the facts and fix the navigation. Do not create a new status artifact.

In `AGENTS.md`:

- Rewrite the "Installed:" sentence so it reflects the real install (23 skills; `skills-lock.json` stays the authoritative list) and the SDLC span they now cover, rather than naming six.
- **Keep** the "Not installed, but referenced" table — it is agent-load-bearing, because a named-but-absent skill is a dead end at dispatch time and nothing is fetched at run time. Reduce it to the rows that are still true: `om-auto-fix-pr`, `om-followup-issue-from-pr`, `om-review-prs`, `om-merge-buddy`, `om-close-fixed-issues`. Add `om-auto-continue-pr-loop`, which is genuinely absent and which the table never listed (the v16 map already tracks it as a gap). Delete only the seven rows that are now false.
- Add a task-routing row for orientation: when the question is "where am I in the lab / what has been exercised", read the current learning map's coverage and knowledge-gap sections. The same row records the maintenance ritual — updating those two sections is the last step of every lesson — and the status convention: three states only (`OBSERVED` / `DOCUMENTED` / `NOT TESTED`), with any partial-coverage nuance carried in the note text rather than by inventing composite statuses.

In `README.md`:

- Raise the "Visual map" pointer from v5 to v16 as the current revision, and describe the coverage and knowledge-gap sections as the orientation surface, so a returning reader lands on them.
- Fix the `.ai/browsers/agent-browser.md` row, which claims the UI-verification skill is not installed.
- Leave the existing "remove its row from the coverage-gap table in `AGENTS.md`" instruction intact and correct — it stays valid precisely because the table is kept rather than collapsed into a pointer.

Rejected, with reasons:

- **A new `LEARNING-STATUS.md` as a single source of truth.** It would be a second hand-maintained copy of what the v16 map already keeps, in the same three-state vocabulary — the exact second source of truth the change exists to prevent. This was the conversation's favourite until the map was inspected.
- **Deriving status by parsing `EXPERIMENTS.md` for skill mentions.** A mention cannot distinguish `OBSERVED` from `DOCUMENTED`, and that judgment belongs to the operator during the lesson. It would also require a new parsable field plus a backfill of seven entries.
- **A seventeenth HTML artifact / a dashboard.** The repository already carries two scripts, sixteen maps, and two long prose logs; another artifact without an update rule adds drift instead of removing it.
- **Collapsing the `AGENTS.md` coverage section into a bare pointer.** It would delete the five still-true absent-skill rows, which no installed-skills-only document can carry, and would break the README references that depend on that table.
- **"Build nothing" lost only partially, and that is deliberate.** It survives as the decision that no new record is created; what it could not cover is that two navigational documents state falsehoods today, and a returning reader has no path to the map.

## Resolved unknowns

| Question | Answer (from the conversation) |
|----------|--------------------------------|
| Is the pain "the data is scattered" or "the data does not exist"? | Neither, as it turned out: the data exists and is well-structured inside `learning-map/om-skills-learning-map-v16.html`. The pain is that nothing points at it, and the documents that are read instead are wrong. |
| Should "exercised" status be hand-maintained or derived from the log? | Hand-maintained. The operator alone decides whether something was truly observed; mentions in prose cannot express that distinction. |
| Where does the truth about coverage live? | In the learning map, unchanged. No new file is created now. |
| How many status states, and how is partial coverage expressed? | Three states — `OBSERVED` / `DOCUMENTED` / `NOT TESTED`. Partial coverage goes into the note text; composite statuses are explicitly rejected as they make the vocabulary grow without bound. |
| Should `lab-report.ps1` parse or render the coverage status? | No. No new format contract and no new script logic in this change. |
| Should the `AGENTS.md` "not installed" table be removed? | No — it must be kept and corrected. Five of its rows are true and load-bearing for dispatch, and an installed-skills-only document cannot hold them. |
| Is this change worth a spec? | No. Correcting specific false statements and adding two pointers leaves a reviewer nothing to react to design-wise. |
| How do we know whether this is enough? | The next break is the experiment. If the corrected `AGENTS.md` plus the v16 gap list orient the operator on return, the rejected `LEARNING-STATUS.md` was never needed; if not, the fallback is extracting the map's coverage and gap sections into a text file and having v17+ stop authoring them. |

## Non-goals

- Creating `LEARNING-STATUS.md`, or any other new status file.
- Any change to `.ai/scripts/lab-report.ps1` or `.ai/scripts/lab-status.ps1`, including having either read the map or a status file.
- Generating a v17 learning map, editing the content of the v16 map, or deleting older map revisions.
- Fixing anything in `EXPERIMENTS.md` or `FINDINGS.md`, including adding structured fields or backfilling entries.
- Auditing the remaining `AGENTS.md` or `README.md` claims beyond the ones named above.
- Installing any of the still-absent skills.

## Affected areas (if known)

- `AGENTS.md` — the section "Installed skills and known coverage gaps" (the "Installed:" sentence and the "Not installed, but referenced" table), and the "Task routing" table, which gains the orientation row.
- `README.md` — the `.ai/browsers/agent-browser.md` row in the repository map (the "not installed here" claim), and the "Visual map" section naming v5 as current. The "Repository map" row for `learning-map/` may need the same v16 alignment.
- `learning-map/om-skills-learning-map-v16.html` — read as the source of truth for what the pointers should say; not edited.
- `skills-lock.json` and `.agents/skills/` — read to state the install count correctly; not edited.
