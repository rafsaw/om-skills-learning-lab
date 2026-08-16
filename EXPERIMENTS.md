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

---

## Experiment 004 — Autonomous spec implementation lifecycle

### Goal

Observe how Open Mercato takes an approved specification already merged to `main` and turns it into a controlled implementation run.

The experiment focused on the fresh implementation path:

```text
approved spec
→ om-auto-implement-spec
→ om-auto-create-pr
→ implementation PR
```

Resume behavior through `om-auto-continue-pr` was intentionally left for a separate experiment.

### Starting state

The repository was on a clean `main` branch, up to date with `origin/main`.

The approved specification already existed on `main`:

```text
.ai/specs/2026-08-13-lab-status-check.md
```

The specification came from the design-only PR:

```text
#9 — docs(specs): lab status check
```

The implementation skills had been installed before the experiment:

```text
om-auto-implement-spec
om-auto-create-pr
```

No implementation branch, worktree, execution plan, Issue, or implementation PR was created manually.

### Run

The approved specification was passed directly to:

```text
om-auto-implement-spec .ai/specs/2026-08-13-lab-status-check.md
```

`om-auto-implement-spec` resolved the specification by its exact repository-relative path.

The spec PR was already merged, so the specification was available on `main` and did not need to be materialized from a separate spec branch.

No existing implementation PR referencing the specification was found, so the orchestrator selected the fresh implementation path:

```text
om-auto-implement-spec
→ om-auto-create-pr
```

### Engine selection

`om-auto-create-pr` generated an execution plan from the specification's `Implementation Plan`.

The resulting plan contained:

```text
5 Steps
```

The configured threshold was:

```text
engine.loopStepThreshold = 20
```

`--loop` was not supplied.

The selected engine was therefore:

```text
Engine: om-auto-create-pr (steps: 5, --loop: no)
```

`om-auto-create-pr-loop` was not exercised.

### Branch and isolated worktree

The implementation used the branch:

```text
feat/lab-status-check
```

An isolated implementation worktree was created under:

```text
.ai/tmp/om-auto-create-pr/
```

The primary checkout remained on `main`.

The temporary implementation worktree was removed at the end of the run. A later:

```text
git worktree list --porcelain
```

showed only the primary repository worktree.

### Durable execution plan

The first commit on the implementation branch was:

```text
7c22dd7 docs(runs): add execution plan for lab-status-check
```

This confirmed that the execution plan became a durable repository artifact before feature implementation commits were created.

The plan tracked implementation progress and was updated as work completed.

### Incremental implementation

The implementation proceeded through incremental commits:

```text
ef6114b feat(scripts): add lab-status.ps1 skeleton with anchor check and verdict
c346238 feat(scripts): report branch and working-tree state in lab-status
6af942f feat(scripts): check skill discovery resolution and lockfile drift
f697ca6 feat(scripts): report the latest recorded experiment and finding
a347cc6 docs(readme,agents): point at lab-status.ps1 as the session-readiness check
```

After the implementation phase completed, Progress was recorded separately:

```text
eda21c4 docs(runs): mark lab-status-check Phase 1 complete
```

This provided a durable relationship between the execution plan, completed implementation work, and Git history.

### Validation

The repository-configured validation gate was:

```text
git diff --check
```

It passed.

The run additionally performed specification-specific verification, including PowerShell parsing and execution against multiple repository-state scenarios.

### Review/autofix

The implementation then entered the already-known downstream review subsystem:

```text
om-auto-review-pr --autofix
```

The first review requested changes.

A real Windows PowerShell 5.1 compatibility issue was identified: repository Markdown files encoded as UTF-8 without BOM were being read using the host's default encoding.

The fix was committed as:

```text
4a2e036 fix(scripts): read repository text as UTF-8 regardless of the host code page
```

The execution plan was updated again to record the review autofix:

```text
fdf642b docs(runs): record the review autofix commit
```

The subsequent review passed.

GitHub did not allow the automation account to formally approve its own PR. The review verdict was therefore represented through PR conversation comments and pipeline state rather than a native approving review.

### Implementation PR

The implementation was published separately from the design PR:

```text
#10
```

on:

```text
feat/lab-status-check
```

The implementation PR referenced the approved specification, while spec PR `#9` remained design-only.

`om-auto-implement-spec` also posted an implementation cross-link on spec PR `#9`.

The final implementation PR was left ready for human review/merge.

### UI verification

UI verification was not run.

The implementation consisted of a PowerShell terminal script and documentation pointers and did not modify an application UI.

The run therefore reported:

```text
UI: n/a
```

and used `skip-qa`.

### Observed flow

```text
approved spec on main
        ↓
om-auto-implement-spec
        ↓
resolve spec
        ↓
search for existing implementation
        ↓
no implementation PR
        ↓
om-auto-create-pr
        ↓
execution plan from spec
        ↓
5 Steps
        ↓
flat engine selected
        ↓
isolated worktree
        ↓
feat/lab-status-check
        ↓
execution-plan commit
        ↓
draft implementation PR
        ↓
incremental implementation commits
        ↓
Progress update
        ↓
validation
        ↓
review / autofix
        ↓
Progress update
        ↓
ready implementation PR
        ↓
temporary worktree cleanup
```

### Evidence status

Observed in this experiment:

```text
● om-auto-implement-spec resolving an approved spec from main
● fresh-run routing to om-auto-create-pr
● execution-plan generation from the spec
● Step counting and flat-engine selection
● isolated implementation worktree
● separate feat/ implementation branch
● execution plan committed before implementation code
● incremental implementation commits
● durable Progress tracking
● validation before completion
● downstream review/autofix
● separate design and implementation PRs
● ready implementation PR
● temporary worktree cleanup
```

Documented but not exercised:

```text
○ om-auto-create-pr-loop
○ automatic routing for plans above the Step threshold
○ --loop
○ --force
```

Not tested:

```text
◌ om-auto-continue-pr resume path
◌ om-auto-continue-pr-loop
◌ interruption and resume behavior
◌ claim-conflict behavior
◌ implementation from an unmerged spec PR
```

---

## Experiment 005 — Loop implementation engine and durable execution protocol

### Goal

Observe the runtime behavior of `om-auto-create-pr-loop` during a real feature implementation and verify whether it uses a meaningfully different execution model from the plain `om-auto-create-pr` engine.

The experiment deliberately focused on the loop concept itself. Interruption/resume, stale locks, and `om-auto-continue-pr-loop` were left out of scope.

### Starting point

A new Learning Lab feature was first described as a normal feature brief and passed through the already-known design path:

```text
feature brief
    ↓
om-auto-write-spec
    ↓
design-only spec PR #11
```

The resulting specification was:

```text
.ai/specs/2026-08-15-lab-report.md
```

It designed a read-only Windows PowerShell 5.1 script:

```text
.ai/scripts/lab-report.ps1
```

The spec PR remained open and design-only.

### Run

The implementation was started through the normal spec implementation entry point, but with loop execution explicitly forced for the experiment:

```text
om-auto-implement-spec .ai/specs/2026-08-15-lab-report.md --loop
```

`om-auto-implement-spec` resolved the specification from the supplied path.

Because the spec was not yet on `main`, it was materialized into the implementation worktree from spec PR #11 for reference only and was not committed to the implementation branch.

The fresh implementation route delegated to `om-auto-create-pr`, and the forwarded `--loop` flag caused an immediate handoff to:

```text
om-auto-create-pr-loop
```

The engine report was:

```text
Engine: om-auto-create-pr-loop (steps: n/a, --loop: yes)
```

The Step count is `n/a` because `--loop` forced the handoff before the plain engine drafted and counted a plan.

The loop engine then produced a six-Step implementation plan. Without `--loop`, this feature would have remained under the configured threshold of 20 Steps and would have used the plain engine.

### Observed loop execution model

The run used the branch:

```text
feat/lab-report
```

The implementation used the loop engine's durable run-folder contract rather than the plain single-plan-file contract.

Observed execution included:

```text
run folder
    ↓
PLAN.md with authoritative Tasks state
HANDOFF.md
NOTIFY.md
checkpoint state
final-gate state
```

Implementation proceeded Step-by-Step, with one commit per implementation Step.

The run contained six planned Steps and produced eleven commits in total, because durable execution-state commits were added alongside the implementation commits, including the run-folder, checkpoint, and close-out commits.

A checkpoint fired during the run after the first group of Steps, exercising the checkpoint-based verification model rather than only end-of-run validation.

The final gate completed successfully.

### Validation and review

The repository-configured gate:

```text
git diff --check
```

passed.

Additional verification included PowerShell parsing and a manual verification fixture covering 28 cases across the implementation Steps using scratch repositories under `$env:TEMP`.

The verification found real implementation defects before the affected commits landed, including a version that exited successfully while producing no output.

The authoritative review path ran through:

```text
om-auto-review-pr
    ↓
om-code-review
```

The final review verdict was approve.

One major finding about the absence of a test file was waived because the Learning Lab repository has no test runner or CI. Two minor findings were fixed in a follow-up commit.

### Implementation PR

The implementation was published as:

```text
PR #12
```

The spec PR and implementation PR remained separate:

```text
PR #11 = design-only specification
PR #12 = feature implementation
```

PR #12 was left ready for review.

### Result

Confirmed that `om-auto-create-pr-loop` is not merely the plain implementation engine running for more iterations.

The loop engine uses a different durable execution contract:

```text
PLAN / Tasks
    +
HANDOFF
    +
NOTIFY
    +
Step-level commits
    +
checkpoint verification
    +
final gate
        ↓
durable loop execution state
```

The experiment also confirmed that forcing `--loop` is useful for studying the execution model independently of the Step-count routing threshold.

Observed in this experiment:

```text
● --loop forcing handoff to om-auto-create-pr-loop
● loop execution on a real spec implementation
● run-folder durable state
● PLAN.md Tasks-based execution state
● one implementation Step per commit
● checkpoint execution during the run
● final-gate execution
● separate spec and implementation PRs
● ready implementation PR
```

Documented but not exercised:

```text
○ automatic loop routing when Step count exceeds engine.loopStepThreshold
○ executor subagent dispatch
○ Simple → Spec-implementation promotion
```

Not tested:

```text
◌ interruption and resume
◌ om-auto-continue-pr-loop runtime behavior
◌ multi-session handoff
◌ stale-lock recovery
```

---

## Experiment 006 — QA environment discovery and no-app boundary

### Goal

Test how `om-prepare-test-env` consumes the repository's QA-related configuration and observe its runtime behavior when the repository has no runnable application.

The experiment was intentionally scoped to environment discovery and QA configuration rather than a full browser-driven QA run.

The main question was:

```text
agentic.config.json
        ↓
om-prepare-test-env
        ↓
can it produce an honest runtime contract
for this repository?
```

### Starting state

The Learning Lab configuration already contained:

```text
paths.qa         = .ai/qa
paths.scripts    = .ai/scripts
browser.provider = agent-browser
qaGate           = false
```

The repository itself had no application runtime.

A recursive check found no common application or environment definitions:

```text
no package.json
no *.csproj / *.sln
no Dockerfile
no docker-compose*.yml / compose*.yml
no pyproject.toml / requirements.txt
no Cargo.toml
```

The repository also had no `.github/workflows/` directory.

`AGENTS.md` and `README.md` both documented that the Learning Lab contains no application source tree or test suite.

The only browsable artifacts were the self-contained Learning Map HTML files under:

```text
learning-map/
```

### Run

`om-prepare-test-env` performed repository discovery and reported the runtime facts it found.

It identified that there was no actual application to bring up, but also noticed that the self-contained Learning Map HTML files could technically be served over HTTP.

Rather than silently inventing a target, the skill surfaced an explicit choice:

```text
There is no app in this repo. What should the generated test environment actually bring up?

1. Static server for learning-map/
2. Static server for repo root
3. No app — record the gap
```

The selected answer was:

```text
No app — record the gap
```

The skill then asked which script flavor should be used if environment scripts were ever generated for this repository.

The selected answer was:

```text
PowerShell .ps1
```

This matched the repository's existing Windows PowerShell tooling and the documented PowerShell 5.1 execution convention.

### Observations

The run completed with:

```text
no environment applicable
```

and explicitly treated that conclusion as a valid discovery result rather than a provisioning failure.

No environment scripts were generated:

```text
.ai/scripts/test-env-up.ps1    → not created
.ai/scripts/test-env-down.ps1  → not created
```

No server was started.

No readiness probe was run.

No base URL was fabricated.

The skill wrote:

```text
.ai/qa/test-env.json
```

with the observed state:

```text
status            = no-app
mode              = none
baseUrl           = null
startedByThisRepo = false
startScript       = null
stopScript        = null
services          = []
credentials       = []
testRunner.name   = none
platform          = win32
```

The configured browser provider propagated into the descriptor:

```text
browser.provider  = agent-browser
browser.installed = false
```

`agent-browser` was deliberately not installed because there was no application for it to drive.

This avoided downloading and provisioning browser tooling that had no runtime target.

The descriptor therefore acted as an explicit negative environment contract:

```text
status = no-app
baseUrl = null
        ↓
runtime consumers must not attach
```

The skill also created a tracked repo-local extension:

```text
.ai/skills/om-prepare-test-env/SKILL.md
```

That file persisted the discovery result so future runs do not have to repeat the same repository analysis.

It recorded:

```text
the no-application conclusion
supporting repository evidence
machine/tooling facts
PowerShell 5.1 constraints
the chosen .ps1 flavor
instructions for QA consumers
browser-provider deferral
explicit re-attempt triggers
```

The re-attempt triggers include adding a real application manifest, Docker/Compose setup, CI workflow, changing the relevant `AGENTS.md` state, or deliberately deciding to serve `learning-map/` as a browser QA target.

The repository validation gate:

```text
git diff --check
```

passed.

### Result

Confirmed that `om-prepare-test-env` consumes the repository's QA environment configuration and can produce an honest runtime contract even when no runnable application exists.

The observed runtime path was:

```text
agentic.config.json
        ↓
om-prepare-test-env
        ↓
repository discovery
        ↓
no runnable application
        ↓
explicit human target decision
        ↓
no fake server
no fake baseUrl
no fake readiness
        ↓
test-env.json
status = no-app
baseUrl = null
```

The experiment also confirmed that environment discovery can persist repository-specific knowledge through a repo-local skill extension instead of forcing future runs to repeat the same discovery.

Observed in this experiment:

```text
● om-prepare-test-env repository discovery
● consumption of the configured QA path and browser provider
● explicit no-app decision boundary
● PowerShell .ps1 flavor selection for this Windows repository
● no generated environment scripts when no application exists
● no server or readiness probe when there is no runtime target
● test-env.json written with status=no-app and baseUrl=null
● browser.provider=agent-browser propagated into the descriptor
● browser provider deliberately left uninstalled
● repo-local .ai/skills/om-prepare-test-env/SKILL.md created
● repository-specific evidence and re-attempt triggers persisted
● git diff --check passed
```

Documented but not exercised:

```text
○ generated test-env-up.ps1 / test-env-down.ps1
○ cold-run environment generation
○ warm-run environment reuse
○ build-cache behavior
○ browser-provider ensure-installed / doctor success path
```

Not tested:

```text
◌ real runnable application boot
◌ real agent-browser open / snapshot / interact / assert
◌ full om-auto-qa-pr runtime scenario
◌ screenshot evidence and report PASS / FAIL
◌ qaGate=true merge-blocking behavior
◌ self-QA label mutation
◌ om-integration-tests authoring against a real application
```

