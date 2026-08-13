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
