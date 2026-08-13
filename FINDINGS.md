# OM Skills Learning Lab – Findings

## Finding 001  (Lesson 1-2)

### Question

What is the first Open Mercato skill?

### Evidence

`om-setup-agent-pipeline` states:

> "It is the first skill to run in a fresh repository."

### Observation

The setup created:

- .ai/
- AGENTS.md
- SDLC.md
- CODE_REVIEW.md
- BACKWARD_COMPATIBILITY.md

### Conclusion

The engineering pipeline is bootstrapped before any implementation skills are used.

---

## Finding 002 (Lesson 1-2)

### Question

What is the central configuration?

### Evidence

SKILL.md:

> "Every skill reads `.ai/agentic.config.json`."

### Observation

The config contains:

- validation
- labels
- tracker
- paths
- engine

It contains no application framework configuration.

### Conclusion

Open Mercato centralizes engineering-process configuration rather than application-stack configuration.

---

## Finding 003

### Question

Why does `AGENTS.md` exist if `.ai/agentic.config.json` already exists?

### Evidence

`AGENTS.md` contains a **Task routing** section that maps task types to the documents an agent should read first (for example, pipeline changes → `.ai/agentic.config.json` + `SDLC.md`, skill editing → `SKILL.md` + `references/`).

`.ai/agentic.config.json` contains only structured pipeline configuration such as validation commands, labels, engine settings and artifact paths.

### Observation

The two files have different responsibilities.

- `agentic.config.json` configures the engineering pipeline.
- `AGENTS.md` explains how an agent should navigate the repository and which documents become authoritative for a given task.

### Conclusion

Open Mercato separates **configuration** from **repository guidance**.

`agentic.config.json` defines **how the pipeline is configured**, while `AGENTS.md` acts as a **knowledge router**, directing agents to the correct documentation before making changes.

---

## Finding 004 — Lesson 4: Pipeline execution through skills

### Question

What does running a change through the pipeline reveal about how the skills relate to each other?

### Evidence

Issue #2 and PR #3 — the issue-driven run: the issue was assigned and claimed by comment before work started.

PR #4 — the branch-driven run: label transitions from `review` to `changes-requested` to `merge-queue`, the claim and release around the review stage, the rejected same-account approval, and the merge.

### Observation

A real repository change was taken through the Open Mercato workflow using pipeline skills. GitHub labels represented workflow states, and dedicated skills handled review, autofix, re-review, merge queue, and merge. Claiming is not uniform across the skills: `om-auto-review-pr` claimed the PR with an assignee, the `in-progress` label, and a claim comment, and released the claim when its stage finished, while `om-open-pr` and `om-approve-merge-pr` acted on the PR without taking the lock at all. The claim is the mechanism intended to keep concurrent agents off the same PR, although no contention actually occurred during these runs.

### Conclusion

The Open Mercato pipeline is not one monolithic agent workflow. It is composed of specialized skills that perform individual SDLC stages and coordinate through shared repository state, primarily GitHub issues, PRs, claims, and labels.

This allows work to move between agents and skills while the repository and tracker remain the shared source of workflow state.

## Finding 005 — Issue orchestration is explicit and resumable

`om-auto-fix-issue` acts as a high-level flow runner for a single issue-driven session. It does not implement every SDLC stage itself; instead, it orchestrates specialized companion skills and controls routing, sequencing, worktree lifecycle, concurrency, handoffs, failure cleanup, and reporting.

Skills communicate through explicit contracts such as machine-readable reference lines, control markers, structured previous-step outputs, and tracker state. The process can stop cleanly and later resume from durable repository/tracker state rather than depending on one continuous agent session.

This creates a layered model:

`flow runner → specialized skills → repo/tracker state`

The orchestration layer coordinates the workflow while individual skills retain narrow responsibilities and remain independently runnable.
