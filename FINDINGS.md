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

---

## Finding 006 — Feature design is a separate autonomous lifecycle

### Question

After autonomous issue orchestration, does Open Mercato treat feature design as just another implementation step, or as its own lifecycle?

### Evidence

Lesson 6 used `om-auto-write-spec` with a plain feature brief for a Learning Lab Status capability.

The skill created an isolated `spec/lab-status-check` branch, wrote `.ai/specs/2026-08-13-lab-status-check.md`, and opened PR #9 as a design-only PR. No feature code was implemented in that PR.

`om-spec-writing` produced the specification in autonomous mode, including resolved assumptions, architecture, edge cases, phasing, and an implementation plan.

### Observation

The feature moved through a complete design lifecycle before implementation began:

`feature brief → autonomous spec → spec PR → review → human decisions → spec amendment → approved spec on main`

The spec PR remained explicitly design-only, and the implementation was left for a separate follow-on lifecycle.

### Conclusion

Open Mercato treats feature specification as a first-class, independently reviewable engineering artifact rather than as hidden reasoning inside an implementation run.

The lifecycle separates **design state** from **implementation state**, allowing the design to be reviewed, amended, merged, and referenced before any code is written.

---

## Finding 007 — Autonomous design is reversible and human-overridable

### Question

What happens when an autonomous spec is technically valid but the human disagrees with its product or implementation decisions?

### Evidence

The first autonomous version of the Lab Status spec selected a POSIX shell script and a broader diagnostic scope.

An architectural review found several correctness issues, but it did not reject those product decisions.

Human review then explicitly changed two decisions:

- use Windows PowerShell 5.1 instead of POSIX `sh`,
- reduce Phase 1 to the smallest useful Learning Lab Status capability.

`om-spec-writing` amended the existing spec in place and regenerated the affected architecture, contracts, risks, phasing, and implementation plan.

### Observation

Autonomous defaults were not treated as final authority.

The design could be narrowed and redirected after review without discarding the spec lifecycle or starting over. The revised spec preserved an audit trail of the original autonomous decisions and the later human overrides.

### Conclusion

Open Mercato autonomy is designed around **documented, reversible assumptions**, not irreversible agent decisions.

A useful mental model is:

`autonomous proposal → explicit assumptions → review → human override → amended durable artifact`

Human judgement remains a first-class control point, especially for scope and environment-specific decisions that architectural review alone may not identify.

---

## Finding 008 — Runtime repository state can correct documented assumptions

### Question

When repository documentation and the actual checkout disagree, which one should drive the design?

### Evidence

During the Lab Status spec amendment, repository probing showed that the 13 discovery entries under `.claude/skills/` were NTFS `Junction` entries in the Windows checkout, even though the repository documentation consistently described them as symlinks.

A design that accepted only `SymbolicLink` would therefore have reported a healthy lab as broken.

The final spec was changed to accept both `SymbolicLink` and `Junction` and to verify that each discovery entry resolves to the matching `.agents/skills/<name>` directory in the current repository.

### Observation

The spec-writing/review process used actual repository state to challenge a documented assumption and changed the design accordingly.

### Conclusion

Repository documentation is an important source of architectural intent, but runtime and filesystem observations remain authoritative for actual behavior.

For feature design, Open Mercato's process can be understood as:

`repo rules + repo state + observed runtime behavior → design`

rather than treating documentation alone as unquestionable truth.

