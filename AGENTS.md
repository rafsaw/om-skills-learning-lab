# AGENTS.md

## Project overview

`om-skills-learning-lab` is a sandbox repository for learning and exercising the [open-mercato](https://github.com/open-mercato/skills) agent-skill collection. It contains no application code: the substance of the repo is Markdown skill definitions and the agentic pipeline configuration that drives them. Skills are installed as vendored copies (not submodules) and pinned by content hash in `skills-lock.json`, so the repo is a reproducible snapshot of a skill set that can be edited, broken, and re-run safely.

Because there is no build system, "working on this repo" almost always means editing Markdown that an agent will later execute as instructions. Treat every file here as executable prose: a careless edit to a `SKILL.md` changes agent behavior as surely as a code change would.

## Repository layout

```
.agents/skills/<skill-name>/     canonical skill source (SKILL.md + references/)
.claude/skills/<skill-name>      symlink → ../../.agents/skills/<skill-name>
.claude/settings.local.json      local permission allowlist (not team config)
.ai/agentic.config.json          pipeline config every om-* skill reads
.ai/trackers/github.md           tracker operation definitions (gh CLI)
.ai/browsers/agent-browser.md    browser operation definitions
.ai/{runs,analysis,specs,scripts,qa}/   skill working directories
skills-lock.json                 installed-skill manifest: source + computedHash
SDLC.md CODE_REVIEW.md BACKWARD_COMPATIBILITY.md   process docs
```

Discovery entries are not committed: `.claude/` is gitignored, so after a fresh clone the skills exist under `.agents/skills/` but nothing can dispatch to them until the symlinks are recreated (Windows needs Developer Mode or an elevated shell):

```bash
mkdir -p .claude/skills
for s in .agents/skills/*/; do
  ln -sfn "$PWD/${s%/}" ".claude/skills/$(basename "$s")"
done
```

## Installed skills and known coverage gaps

`skills-lock.json` is the authoritative list of what is installed; this section records what is *not*, because the installed skills reference absent ones by name and an agent that follows those references finds nothing. Nothing is fetched at run time, so a named-but-absent skill is a dead end, not a lazy install.

Installed: `om-setup-agent-pipeline`, `om-code-review`, `om-auto-review-pr`, `om-open-pr`, `om-approve-merge-pr`, `om-check-and-commit`. Together these cover the SDLC stages from *PR* through *Review loop* to *Merge* — a branch can be committed, opened as a labeled PR, reviewed, and merged without leaving the local install.

Not installed, but referenced by the skills above:

| Referenced skill | Named by | What is unavailable here |
|---|---|---|
| `om-auto-fix-pr` | `om-approve-merge-pr` (conflicts, red CI, `changes-requested`) | The blocker-recovery route. A conflicted or CI-red PR must be fixed by hand or through `om-auto-review-pr --autofix`, which fixes findings but is not the `--ci-only` path. |
| `om-followup-issue-from-pr` | `om-approve-merge-pr` | Filing a follow-up issue from a PR or comment link; open the issue manually. |
| `om-auto-create-pr`, `om-auto-continue-pr` | `om-open-pr`, `om-code-review`, `SDLC.md` | Alternative PR-opening callers. No loss: `om-open-pr` is the shared implementation they delegate to and works standalone. |
| `om-auto-qa-pr` | `om-open-pr` (`references/pr-finalize.md`) | The manual-QA pass and the self-QA `qa-approved` exception. The QA gate is off (`qaGate: false`), so this blocks nothing today. |
| `om-review-prs` | `om-code-review`, `SDLC.md` | Batch review across open PRs; review them one at a time with `om-auto-review-pr` instead. |
| `om-merge-buddy`, `om-close-fixed-issues` | `SDLC.md` | The read-only "which PRs can merge now" report, and post-merge issue housekeeping. |
| `om-auto-write-spec`, `om-auto-implement-spec` | `om-open-pr` | The spec-driven run that hands `om-open-pr` a spec-only design PR. |
| `om-spec-writing`, `om-brainstorm` | `BACKWARD_COMPATIBILITY.md` §5, `om-auto-review-pr` (`references/spec-review.md`) | The `paths.specs` handoff chain that produces the specs a spec-only PR reviews. |

Add one with `npx skills add` (never by hand-copying — the lockfile hash comes from the tool) and delete its row here in the same PR.

## Task routing

| When the task involves… | Read first | Key rules |
|---|---|---|
| Editing or authoring a skill | `.agents/skills/<name>/SKILL.md`, then its `references/*.md` | `SKILL.md` needs YAML frontmatter with `name` (matching the directory) and a `description` written as trigger conditions, since that text is all a dispatcher sees. Keep `SKILL.md` the router and push detail into `references/` — the existing skill loads references on demand rather than inlining them. Cross-file pointers use the `om-<skill>/references/<file>` form. |
| Adding or updating an installed skill | `skills-lock.json` | Skills are vendored via `npx skills add`, not hand-copied: each entry pins `source`, `sourceType`, `skillPath`, and a `computedHash`. Editing a vendored skill in place invalidates its hash — that is expected in a learning lab, but say so in the PR body so the drift is intentional and visible. |
| Checking whether the repo is session-ready | `.ai/scripts/lab-status.ps1` | Run `powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-status.ps1` before starting work. It is read-only and reports branch and working-tree state, whether every `.claude/skills/` entry resolves into *this* checkout, and the latest recorded experiment and finding. Exit `0` means ready, `1` means at least one blocker, `2` means it was run outside this lab. It never repairs what it finds — recreating a discovery entry stays a deliberate human step. |
| Summarizing what the lab currently contains | `.ai/scripts/lab-report.ps1` | Run `powershell -NoProfile -ExecutionPolicy Bypass -File .ai\scripts\lab-report.ps1` to render repository status, installed skills, available specs, and the learning log as one Markdown document; add `-OutFile <path>` to write it (never `>`, which writes UTF-16 in PowerShell 5.1). The two scripts answer different questions and must not be conflated: `lab-status.ps1` asks *is this repository ready?* and gates on the answer through its exit code, while `lab-report.ps1` asks *what does this repository contain?*, renders no verdict, and exits non-zero only when it could not produce a report at all. The report defers every discovery diagnosis to `lab-status.ps1` rather than restating it. |
| Skill discovery / a skill not being found | `.claude/skills/`, `.claude/settings.local.json` | `.claude/skills/<name>` entries are **symlinks** into `.agents/skills/`, not copies. Never replace a symlink with a directory — that forks the skill into two divergent sources. On Windows these symlinks require Developer Mode or elevation to recreate; if one is broken, recreate the link rather than copying files. |
| Pipeline configuration or behavior | `.ai/agentic.config.json`, `SDLC.md` | The config and `SDLC.md` describe the same process and change together. Do not hand-edit the label taxonomy in one place only. Re-run `om-setup-agent-pipeline` when the toolchain or taxonomy changes. |
| Tracker or browser behavior | `.ai/trackers/github.md`, `.ai/browsers/agent-browser.md` | These committed descriptors are authoritative and are the intended extension point — override an operation here rather than forking a skill. Skills never call `gh` directly; they name operations that this file defines. |
| Repo-specific skill overrides | `.ai/skills/<skill-name>/SKILL.md` (none exist yet) | A repo-local skill extends the installed one of the same name; repo specifics win. It can never relax safety rules, widen tool or network access, or redirect outputs. |
| Process, review, or compatibility questions | `SDLC.md`, `CODE_REVIEW.md`, `BACKWARD_COMPATIBILITY.md` | `CODE_REVIEW.md` is applied automatically by `om-code-review`. |
| Anything under `.ai/runs`, `.ai/analysis`, `.ai/qa/artifacts_*` | — | Generated per run, not source. `.ai/qa/artifacts_*/` and `.ai/qa/test-env.json` are gitignored; do not commit them or treat their contents as authoritative. |
| Application code, tests, CI | — | **TODO** — none exists yet. This repo has no source tree, test suite, or `.github/workflows/`. Populate this row before adding one. |

## Validation

Run before opening a PR:

```bash
git diff --check
```

That is the entire gate. There is no compiler, linter, or test runner in this repo — see the validation gate section of `SDLC.md` for why, and add commands to `.ai/agentic.config.json` (not just here) if that changes.

## Conventions observed in this repo

- **Markdown is the product.** Prose is precise and imperative; ambiguity in a skill file becomes an agent bug.
- **Reference-per-concern.** Long procedures live in `references/<topic>.md` and are pointed at from `SKILL.md`, keeping the entry file scannable.
- **Descriptors over hardcoding.** Tracker and browser mechanics are defined in committed descriptor files so behavior is editable without forking skills.
- **Nothing is fetched at run time.** Skills are invoked by exact name from the local install; the lockfile is the source of truth for what is present.

## Pointers

- Process: `SDLC.md`
- Review rules: `CODE_REVIEW.md`
- Protected surfaces: `BACKWARD_COMPATIBILITY.md`
- Pipeline config: `.ai/agentic.config.json`
