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

## Task routing

| When the task involves… | Read first | Key rules |
|---|---|---|
| Editing or authoring a skill | `.agents/skills/<name>/SKILL.md`, then its `references/*.md` | `SKILL.md` needs YAML frontmatter with `name` (matching the directory) and a `description` written as trigger conditions, since that text is all a dispatcher sees. Keep `SKILL.md` the router and push detail into `references/` — the existing skill loads references on demand rather than inlining them. Cross-file pointers use the `om-<skill>/references/<file>` form. |
| Adding or updating an installed skill | `skills-lock.json` | Skills are vendored via `npx skills add`, not hand-copied: each entry pins `source`, `sourceType`, `skillPath`, and a `computedHash`. Editing a vendored skill in place invalidates its hash — that is expected in a learning lab, but say so in the PR body so the drift is intentional and visible. |
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
