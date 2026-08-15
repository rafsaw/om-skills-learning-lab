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

---

## Finding 009 — Spec implementation uses a thin router and a separate execution engine

**Evidence:** Experiment 004 — Autonomous spec implementation lifecycle

`om-auto-implement-spec` did not directly perform the feature implementation.

It resolved the approved specification, checked whether an implementation already existed, and selected the appropriate downstream engine.

For a fresh implementation the observed handoff was:

```text
approved spec
    ↓
om-auto-implement-spec
    ↓
resolve spec
    ↓
detect existing implementation
    ↓
none found
    ↓
om-auto-create-pr
```

`om-auto-create-pr` then owned the implementation machinery: execution planning, worktree isolation, incremental implementation, validation, Progress tracking, PR lifecycle, and downstream review.

This establishes a separation between:

```text
spec resolution / routing
```

and:

```text
implementation execution
```

The orchestration layer does not need to duplicate the execution machinery it routes into.

---

## Finding 010 — Approved design is translated into a durable execution artifact before code

**Evidence:** Experiment 004 — Autonomous spec implementation lifecycle

The approved specification was not consumed only as prompt context.

`om-auto-create-pr` used the specification's `Implementation Plan` to generate a five-Step execution plan.

Before implementation code was committed, the plan itself became the first durable commit on the implementation branch:

```text
7c22dd7 docs(runs): add execution plan for lab-status-check
```

The observed transition was therefore:

```text
approved specification
        ↓
Implementation Plan
        ↓
execution Phases / Steps
        ↓
durable execution plan
        ↓
implementation
```

This creates an explicit boundary between **design intent** and **execution state**.

The specification describes what should be built and the approved design constraints. The execution plan represents how that approved design is being carried out in a particular implementation run.

---

## Finding 011 — Resumability is built from durable execution state, not only agent memory

**Evidence:** Experiment 004 — Autonomous spec implementation lifecycle

The fresh implementation run continuously persisted execution state outside the active agent invocation.

Observed durable state included:

```text
implementation branch
execution-plan commit
incremental implementation commits
Progress checklist
commit SHAs associated with completed work
remote pushes
implementation PR
```

Implementation work was committed incrementally, and completion of the implementation phase was separately recorded:

```text
eda21c4 docs(runs): mark lab-status-check Phase 1 complete
```

After review produced an additional fix, Progress was updated again:

```text
fdf642b docs(runs): record the review autofix commit
```

The resulting model is:

```text
execution plan
    +
Progress state
    +
Git history
    +
remote branch
    +
implementation PR
        ↓
durable implementation state
```

This provides the architectural foundation for a resumable implementation lifecycle without relying solely on the context of one running agent.

The actual resume path through `om-auto-continue-pr` was **not tested in Experiment 004**, so this finding does not claim that resume execution itself has been observed.

---

## Finding 012 — Design and implementation are separate but linked lifecycles

**Evidence:** Experiments 003 and 004

Lesson 6 produced the approved design on a design-only PR:

```text
feature intent
    ↓
autonomous specification
    ↓
architectural review
    ↓
human decisions
    ↓
approved spec
    ↓
spec PR #9
    ↓
main
```

Lesson 7 consumed that approved artifact and created a separate implementation lifecycle:

```text
approved spec on main
    ↓
om-auto-implement-spec
    ↓
om-auto-create-pr
    ↓
feat/lab-status-check
    ↓
implementation PR #10
```

The implementation did not reuse or mutate the spec PR branch.

Instead:

```text
PR #9 = design artifact
PR #10 = implementation artifact
```

The two lifecycles remained linked through the specification path and PR cross-references.

The combined observed lifecycle is therefore:

```text
FEATURE INTENT
      ↓
────────────────────────
DESIGN LIFECYCLE
────────────────────────
      ↓
specification
      ↓
review / human override
      ↓
approved design
      ↓
spec PR
      ↓
main
      ↓
────────────────────────
IMPLEMENTATION LIFECYCLE
────────────────────────
      ↓
spec resolution
      ↓
execution plan
      ↓
isolated implementation
      ↓
incremental commits
      ↓
Progress tracking
      ↓
validation
      ↓
review
      ↓
implementation PR
```

Open Mercato therefore treats approved design and implementation as **separate autonomous lifecycles connected by durable handoff artifacts**, rather than as one continuous opaque agent run.

---

## Finding 013 — `om-auto-continue-pr` reconstructs and resumes unfinished PR work

**Evidence:** Lesson 8 — documented inspection of `om-auto-continue-pr`, `references/claim-pr.md`, and `references/worktree-setup.md`

`om-auto-continue-pr` accepts an existing PR number as its primary entry point and reconstructs the implementation context required to continue that PR.

The documented normal resume path is:

```text
PR number
    ↓
claim / concurrency check
    ↓
resolve Tracking plan
    ↓
restore isolated worktree from PR head
    ↓
parse ## Progress
    ↓
cross-check completed commit SHA
    ↓
first unchecked Step
    ↓
continue implementation
```

The skill does not create a fresh implementation branch. It restores the existing PR head in an isolated worktree and continues the existing execution plan.

The resume point is selected at **Step granularity**:

```text
[x] completed Step
[x] completed Step
[ ] first pending Step  ← resume point
[ ] later Step
```

Execution then continues phase-by-phase using the same implementation, validation, Progress-update, review, and finalization discipline as `om-auto-create-pr`.

### Conclusion

`om-auto-continue-pr` is the resume engine for unfinished PR work.

Its role can be summarized as:

```text
om-auto-create-pr
        ↓
creates implementation state
        ↓
unfinished PR
        ↓
om-auto-continue-pr
        ↓
reconstructs implementation context
        ↓
continues from first pending Step
        ↓
finishes PR
```

This behavior is **documented and inspected in Lesson 8 but has not been runtime-tested in the Learning Lab**.

---

## Finding 014 — Resume state is reconstructed from multiple durable surfaces

**Evidence:** Lesson 8 — documented inspection of `om-auto-continue-pr`, `references/claim-pr.md`, and `references/worktree-setup.md`

Lesson 7 showed that autonomous implementation persists execution state outside the active agent invocation.

Lesson 8 clarified how the resume contract uses those artifacts.

The documented state model is:

```text
PR
= resume entry point and coordination surface

Tracking plan
= execution contract

## Progress
= logical completion state

commit SHAs + Git history
= checkpoint verification

remote PR head
= durable implementation source

assignee + in-progress label + claim comments
= concurrency / ownership state
```

Before continuing implementation, `om-auto-continue-pr` reconstructs both execution state and ownership state.

It resolves the plan from the PR, restores an isolated worktree from the existing remote PR head, finds the first unchecked Progress Step, and cross-checks the last recorded completed Step SHA against Git history.

The documented worktree restoration path is:

```text
existing PR
    ↓
headRefName
    ↓
origin/<PR-head>
    ↓
temporary isolated worktree
```

This means normal resume reconstruction depends on durable remote state rather than the previous invocation's local filesystem state.

### Conclusion

Open Mercato resumability is not simply:

```text
read Progress
→ continue coding
```

The documented model is closer to:

```text
coordination state
        +
execution plan
        +
Progress
        +
Git history
        +
remote PR branch
        ↓
reconstruct safe execution context
        ↓
select resume point
        ↓
continue
```

Lesson 7 observed the creation of much of this durable state. Lesson 8 documented how `om-auto-continue-pr` is designed to consume it.

The actual resume reconstruction path remains **not runtime-tested in the Learning Lab**.

---

## Finding 015 — PR adoption normalizes external or undocumented PRs into the standard resume contract

**Evidence:** Lesson 8 — documented inspection of `references/adopt-pr.md`

`om-auto-continue-pr` is not limited to PRs created by `om-auto-create-pr`.

When an existing PR has no usable execution plan, the skill can **adopt** it rather than treating missing pipeline metadata as a terminal error.

The documented adoption path is:

```text
existing PR
    ↓
no usable Tracking plan
    ↓
evidence sweep
    ↓
reconstruct goal and remaining work
    ↓
create canonical execution plan
    ↓
create ## Progress
    ↓
add Tracking plan: to PR
    ↓
ordinary resume machinery
```

The evidence sweep can use:

```text
PR title / body / task lists
comments
review feedback
failing checks
linked issues
specs and design documents
diff
Git history
repository conventions
```

Adoption therefore acts as a normalization layer.

Instead of building a separate execution mechanism for non-pipeline PRs, it converts them into the same durable representation expected by the normal resume engine:

```text
arbitrary PR state
        ↓
ADOPTION
        ↓
execution plan + Progress
        ↓
standard om-auto-continue-pr lifecycle
```

The same mechanism can repair a malformed or missing `## Progress` section without replacing the rest of an existing plan.

For an interactive run, documented `ask` mode can commit and publish the reconstructed plan, release the claim, clean up the worktree, and stop for human confirmation before implementation. This leaves the PR in a durable state that can later be re-entered through the normal resume path.

### Conclusion

Open Mercato's resume architecture is not restricted to work originally created by its own implementation engine.

PR adoption provides an adapter from external or incomplete PR state into the standard execution-plan contract, after which the ordinary resume machinery can take over.

Adoption was **inspected but not runtime-tested in Lesson 8**.
