# Notify — 2026-08-15-lab-report

> Append-only log. Every entry is UTC-timestamped. Never rewrite prior entries.

## 2026-08-15T16:12:46Z — run started

- Brief: implement the spec at `.ai/specs/2026-08-15-lab-report.md` — a read-only Windows PowerShell 5.1 script that renders the Learning Lab's current state as a Markdown report.
- External skill URLs: none.
- Engine: `om-auto-create-pr-loop` (steps: n/a, `--loop`: yes) — routed by the explicit `--loop` flag, before any plan was drafted.
- Classification: Spec-implementation run, by heuristic rule 1 (a `$SPECS_DIR` spec drives the work).

## 2026-08-15T16:12:46Z — decision: every Step is `inline`

- The six Steps build one file and each layers onto helpers introduced by the previous Step, so an executor subagent would re-derive the same context per Step.
- Independently, this session operates under a constraint that prohibits spawning subagents unless the user asks for them, so `inline` is the only available placement. Recorded so the choice is auditable rather than silent.

## 2026-08-15T16:12:46Z — decision: spec materialized but excluded from commits

- `.ai/specs/2026-08-15-lab-report.md` was checked out into the worktree from spec PR #11's head because it is not on `origin/main` yet.
- A linked worktree's `$GIT_DIR/info/exclude` is not consulted by git (the common dir is), so rather than polluting the shared exclude file, every commit in this run uses explicit `git add <path>` and never `git add -A`. The spec stays untracked and unshipped.

## 2026-08-15T16:22:00Z — decision: Commit-column SHAs are backfilled one Step later

- `references/per-step-loop.md` suggests writing a `pending` placeholder and then `git commit --amend` with the SHA git reported. Amending rewrites the commit, so the SHA recorded that way identifies a discarded object.
- Instead each Step commits with `pending` and the **next** Step's commit backfills the previous Step's real short SHA; the final gate backfills the last one. Every recorded SHA is therefore a commit that actually exists on the branch. `Status` is unaffected, so `om-auto-continue-pr-loop`'s resume point (first row not `done`) still works exactly as specified.

## 2026-08-15T16:22:00Z — scope decision: cell escaping introduced in Step 1.2, not 1.5

- The plan assigns escaping to Step 1.5, but Step 1.2 is the first Step to put free repository text (a commit subject) into a Markdown table, and a `|` in a subject would break the table.
- `ConvertTo-CellText` therefore lands in 1.2 rather than shipping a knowingly breakable table for three Steps. Step 1.5 keeps its job: auditing that *every* interpolated value routes through the escaping helpers, and verifying it against a subject and a spec title that both contain `|`.

## 2026-08-15T16:22:00Z — Step 1.1 verification found a real defect before commit

- `if (-not (Write-Report ...))` captured the function's entire success stream, so the stdout report was swallowed into the `if` condition and nothing printed while the exit code still said `0`.
- Fixed by splitting emission from the file write: `Save-Report` handles files only and never writes to the success stream; stdout emission happens inline in `Invoke-Main` where nothing captures it.

## 2026-08-15T16:28:00Z — checkpoint 1 (Steps 1.1-1.5) passed

- `git diff --check` green, 0 parse errors, full fixture matrix verified across two scratch clones under `$env:TEMP`. Details in `checkpoint-1-checks.md`.
- Four real defects were caught before their commits landed: the success-stream capture that silenced stdout, the `[string[]]` empty-string binding that silently broke every spec title, a singular/plural verb disagreement in the discovery note, and a summary that claimed "0 findings" when `FINDINGS.md` was unreadable rather than empty.
- Integration suite and UI verification skipped with reason: this repository has no integration suite and no application, and the deliverable has no graphical surface.
