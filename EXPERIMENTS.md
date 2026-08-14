# OM Skills Learning Lab – Experiments

A log of hands-on Open Mercato pipeline exercises: what was attempted, what
actually happened, and what came of it.

This is the companion to `FINDINGS.md`. A **finding** is a conclusion reached by
reading — a question answered from the documentation. An **experiment** is a
conclusion reached by running something and watching the result. When an
experiment produces a durable insight about how Open Mercato works, record the
run here and the insight there. The split applies from here on: entries already
in `FINDINGS.md` predate it and are not moved back.

Number experiments sequentially (`001`, `002`, …), append new entries to the end
of this file, and separate each one from the entry above it with a `---` rule —
the same convention `FINDINGS.md` uses. The first real run is `001`; the
skeleton below is a template, not an entry, so nothing is holding that number.

## Entry template

Copy this for a new entry and replace `NNN` with the next number:

```markdown
## Experiment NNN

### Goal

_What was being tried, and what outcome was expected._

### Observations

_What actually happened while running it — commands, output, surprises._

### Result

_What the experiment settled: confirmed, refuted, or inconclusive._
```
---

## Experiment 001

### Goal

Run a real repository change through the Open Mercato PR pipeline and observe the pipeline states, claims, review loop, and merge behavior.

Two runs are covered, because no single run exercised every stage: the issue-driven run behind PR #3 (from issue #2), and the branch-driven run behind PR #4, which had no issue at all.

### Observations

- A real GitHub issue was claimed before work started — issue #2 was assigned and claimed by comment before the work that became PR #3.
- Opening the PR applied the expected pipeline, category, QA, priority, and risk labels (PR #4).
- `om-auto-review-pr` claimed the PR while working on it (PR #4).
- Review moved the PR from `review` to `changes-requested`, applied autofixes, re-reviewed it, and moved it to `merge-queue` (PR #4).
- `om-code-review` acted as the review engine used by `om-auto-review-pr`.
- GitHub rejected formal approval because the PR author and reviewer were the same account (PR #4).
- `om-approve-merge-pr` detected that limitation and asked before merging without formal approval (PR #4).
- Review/autofix used isolated worktrees and left local `review/pr-*` branch refs that required cleanup afterwards.

### Result

Confirmed that the Open Mercato pipeline is a stateful workflow coordinated through GitHub claims and labels. Skills perform specific stages of the workflow and can hand work from one stage to the next, including review, autofix, re-review, merge queue, and merge.

## Experiment 002 — Autonomous issue orchestration from a plain brief

### Goal

Observe how Open Mercato handles a plain problem description end to end and identify which skill actually orchestrates the issue-driven workflow.

### Input

Plain problem description:

> The README is too minimal and does not explain the purpose of this learning lab or how to navigate it.

The run was started from the primary checkout on `main`. No issue, branch, worktree, or implementation plan was prepared manually.

### What happened

1. `om-auto-fix-issue` recognized the input as a plain brief and delegated issue creation to `om-prepare-issue`.
2. `om-prepare-issue` searched for duplicates and created Issue #7 with analysis and SDLC classification.
3. `om-auto-fix-issue` classified the issue into the bug route.
4. The first run stopped cleanly because required companion skills were not installed. No claim, branch, worktree, or PR was left behind.
5. After installing the missing companions, `/om-auto-fix-issue 7` resumed work from the existing issue rather than recreating it.
6. `om-verify-in-repo` acted as a read-only triage gate.
7. After triage passed, `om-auto-fix-issue` created an isolated temporary worktree and branch `fix/issue-7-readme-purpose-and-navigation`.
8. `om-root-cause` produced a read-only analysis brief that was passed to `om-fix`.
9. `om-fix` claimed Issue #7, implemented the change, and ran validation.
10. `om-open-pr` created PR #8 and handed the continuous `in-progress` lock from the Issue to the PR.
11. The existing review subsystem processed the PR, including one autofix and re-review.
12. The run released its lock, removed the temporary worktree, and left the primary checkout on `main` untouched.

### Handoff mechanisms observed

The chain used explicit contracts rather than relying only on shared conversational context:

* `Issue: #<number> (...)` — reference handoff.
* `NO_ACTION_NEEDED` — clean-stop control signal.
* `LOW_CONFIDENCE` — analysis-confidence signal that can propagate forward.
* `Status: ready` / `Status: blocked` — implementation-state signal.
* `— PREVIOUS STEP (...) said —` blocks — verbatim context transfer between skills.
* `in-progress` — concurrency lock transferred from Issue to PR.

### Additional observations

* `om-auto-fix-issue` does not install missing companions at runtime. Missing required skills cause a clean stop.
* Claiming occurs only when implementation begins in `om-fix`; read-only triage and analysis do not claim the Issue.
* Worktree isolation keeps the user's primary checkout untouched.
* GitHub prevents formal self-approval when the same account authors and reviews the PR.
* `om-fix` requires regression tests, but this documentation-only repository has no test runner. The configured `git diff --check` gate and manual documentation checks were used instead.

---

## Experiment 003 — Autonomous feature specification lifecycle

### Goal

Start from a small real feature brief and observe how Open Mercato turns feature intent into an approved specification without implementing the feature.

The chosen feature was **Learning Lab Status**: a lightweight way to check whether the Open Mercato Skills Learning Lab is ready for the next learning session.

### Input

The run started from a plain feature brief:

> Add a simple way to check the current status of the Open Mercato Skills Learning Lab.
>
> I want to quickly see whether the repository is ready for the next learning session, including basic repository state, installed Open Mercato skills, and the latest recorded experiment and finding.
>
> Keep the feature lightweight and appropriate for this learning-lab repository.

No Issue or implementation branch was created manually.

### What happened

1. `om-auto-write-spec` accepted the plain brief and ran the feature-design flow autonomously.
2. It created an isolated spec worktree and branch `spec/lab-status-check`.
3. `om-spec-writing --autonomous` produced `.ai/specs/2026-08-13-lab-status-check.md`.
4. The autonomous run resolved seven Open Questions using reversible defaults and surfaced those decisions in the spec and PR.
5. `om-open-pr` published PR #9 as a design-only spec PR. No feature code was implemented.
6. The first autonomous design chose a POSIX `.ai/scripts/lab-status.sh` implementation and included a broader set of readiness checks.
7. `om-spec-writing` was run again in architectural-review mode without modifying the spec. It found no Critical issues, but identified four High findings and several Medium/Low findings affecting correctness and testability.
8. Human review overrode two important design decisions:
   - use Windows PowerShell 5.1 and `.ai/scripts/lab-status.ps1`,
   - reduce Phase 1 to the smallest useful status capability.
9. `om-spec-writing` amended the existing specification in place instead of creating a new spec.
10. During the amendment, repository probing discovered that the current `.claude/skills/` discovery entries are NTFS junctions rather than symbolic links. The design was updated to accept both link types and verify their resolved targets.
11. Two additional small contract amendments corrected PowerShell unsupported-parameter behavior so the spec does not promise an exit code the script cannot control.
12. The amended spec was committed and pushed to the existing spec branch.
13. `om-open-pr` detected and reused existing PR #9, refreshing its body and labels instead of opening a duplicate PR.
14. `om-approve-merge-pr` attempted formal approval. GitHub rejected self-approval because the same account authored the PR.
15. After explicit confirmation, PR #9 was squash-merged into `main` and the remote spec branch was deleted.
16. The final merged PR remained design-only: the approved specification landed on `main`, while feature implementation was deliberately deferred to a later lesson.

### Observations

- `om-auto-write-spec` is a high-level feature-design orchestrator, not merely a Markdown generator.
- `om-spec-writing` has distinct autonomous writing and architectural-review behaviors.
- Autonomous Open Questions can be resolved with reversible defaults instead of blocking an unattended run.
- Human decisions can override autonomous defaults and trigger an in-place spec amendment.
- An architectural review can find technical correctness issues without necessarily catching product/context choices such as the preferred implementation language or desired scope.
- The spec lifecycle is isolated from feature implementation: PR #9 contained only the specification.
- Runtime repository probing can invalidate documentation assumptions; the Windows checkout used NTFS junctions where the docs said symlinks.
- `om-open-pr` can reuse an existing PR and refresh stale PR metadata after the underlying spec changes.
- GitHub still prevents same-account formal approval; `om-approve-merge-pr` surfaced the limitation and asked before proceeding.

### Result

Confirmed that Open Mercato provides a complete autonomous **feature specification lifecycle** before implementation:

`brief → autonomous spec → review → human override → amendment → spec PR → merge`

The experiment also confirmed that autonomous design is not treated as final authority. The specification remains a durable, reviewable artifact that can be corrected by architectural review, runtime evidence, and human product judgement before implementation starts.

`om-auto-implement-spec` was not installed or run in this lesson and remains untested for the next lesson.

