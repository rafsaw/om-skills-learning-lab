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
